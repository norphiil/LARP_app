import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../models/api_models.dart';
import 'api_service.dart';
import 'database_service.dart';

class DataService {
  final ApiService _apiService;
  final DatabaseService _databaseService;
  final Connectivity _connectivity;
  final Uuid _uuid;

  DataService({
    required ApiService apiService,
    required DatabaseService databaseService,
  }) : _apiService = apiService,
       _databaseService = databaseService,
       _connectivity = Connectivity(),
       _uuid = const Uuid();

  Future<bool> get isOnline async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Authentication
  Future<AuthResponse> login(String username, String password) async {
    final authResponse = await _apiService.login(username, password);
    
    // Cache user data
    await _databaseService.insertUser(authResponse.user);
    
    return authResponse;
  }

  Future<String> registerInitialAdmin(String username, String email, String password, {String? firstName, String? lastName}) async {
    return await _apiService.registerInitial(username, email, password, firstName: firstName, lastName: lastName);
  }

  Future<bool> canRegisterInitial() async {
    return await _apiService.canRegisterInitial();
  }

  Future<void> logout() async {
    await _apiService.logout();
  }

  Future<User> getCurrentUser() async {
    if (await isOnline) {
      try {
        final user = await _apiService.getCurrentUser();
        await _databaseService.insertUser(user);
        return user;
      } catch (e) {
        // Fallback to cache if API fails
        final cachedUser = await _databaseService.getUser(_apiService.token ?? '');
        if (cachedUser != null) return cachedUser;
        rethrow;
      }
    } else {
      // Offline mode - get from cache
      final cachedUser = await _databaseService.getUser(_apiService.token ?? '');
      if (cachedUser != null) return cachedUser;
      throw Exception('No cached user data available offline');
    }
  }

  // Users management
  Future<UsersListResponse> getUsers({
    int page = 1,
    int limit = 20,
    String search = '',
    String role = '',
  }) async {
    if (await isOnline) {
      try {
        final response = await _apiService.getUsers(
          page: page,
          limit: limit,
          search: search,
          role: role,
        );
        
        // Cache users
        await _databaseService.insertUsers(response.users);
        
        return response;
      } catch (e) {
        // Fallback to cache
        return await _getUsersFromCache(
          page: page,
          limit: limit,
          search: search,
          role: role,
        );
      }
    } else {
      // Offline mode
      return await _getUsersFromCache(
        page: page,
        limit: limit,
        search: search,
        role: role,
      );
    }
  }

  Future<UsersListResponse> _getUsersFromCache({
    int page = 1,
    int limit = 20,
    String search = '',
    String role = '',
  }) async {
    final offset = (page - 1) * limit;
    final users = await _databaseService.getUsers(
      search: search.isNotEmpty ? search : null,
      role: role.isNotEmpty ? role : null,
      limit: limit,
      offset: offset,
    );
    
    final total = await _databaseService.getUsersCount(
      search: search.isNotEmpty ? search : null,
      role: role.isNotEmpty ? role : null,
    );

    return UsersListResponse(
      users: users,
      total: total,
      page: page,
      limit: limit,
    );
  }

  Future<User> getUser(String identifier) async {
    if (await isOnline) {
      try {
        final user = await _apiService.getUser(identifier);
        await _databaseService.insertUser(user);
        return user;
      } catch (e) {
        // Fallback to cache
        final cachedUser = await _databaseService.getUser(identifier);
        if (cachedUser != null) return cachedUser;
        rethrow;
      }
    } else {
      // Offline mode
      final cachedUser = await _databaseService.getUser(identifier);
      if (cachedUser != null) return cachedUser;
      throw Exception('User not found in cache');
    }
  }

  Future<String> createUser(Map<String, dynamic> userData) async {
    if (await isOnline) {
      return await _apiService.createUser(userData);
    } else {
      throw Exception('Cannot create users offline');
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> userData) async {
    if (await isOnline) {
      try {
        await _apiService.updateUser(userId, userData);
        
        // Update cache
        await _databaseService.updateUser(userId, userData);
        
        return;
      } catch (e) {
        // If API fails but we're online, still update cache and create modification record
        await _updateUserOffline(userId, userData);
        rethrow;
      }
    } else {
      // Offline mode - update cache and create modification record
      await _updateUserOffline(userId, userData);
    }
  }

  Future<void> _updateUserOffline(String userId, Map<String, dynamic> userData) async {
    // Update local cache
    await _databaseService.updateUser(userId, userData);
    
    // Create modification record for later sync
    final modification = UserModification(
      id: _uuid.v4(),
      userId: userId,
      modifiedBy: 'current_user', // This should be the current user ID
      modifications: userData,
      synced: false,
      createdAt: DateTime.now(),
    );
    
    await _databaseService.insertModification(modification);
  }

  Future<void> deleteUser(String userId) async {
    if (await isOnline) {
      await _apiService.deleteUser(userId);
      await _databaseService.deleteUser(userId);
    } else {
      throw Exception('Cannot delete users offline');
    }
  }

  // Sync operations
  Future<void> syncData() async {
    if (!await isOnline) {
      throw Exception('Cannot sync while offline');
    }

    try {
      // Get unsynced modifications
      final unsyncedModifications = await _databaseService.getUnsyncedModifications();
      
      // Sync each modification
      for (final modification in unsyncedModifications) {
        try {
          await _apiService.updateUser(
            modification.userId,
            modification.modifications,
          );
          
          // Mark as synced
          await _databaseService.markModificationSynced(modification.id);
        } catch (e) {
          print('Failed to sync modification ${modification.id}: $e');
          // Continue with other modifications
        }
      }

      // Refresh cached data
      await _refreshCache();
      
    } catch (e) {
      throw Exception('Sync failed: $e');
    }
  }

  Future<void> _refreshCache() async {
    // This could be optimized to only refresh changed data
    // For now, we'll keep the existing cache and let individual operations update it
  }

  Future<List<UserModification>> getUnsyncedModifications() async {
    return await _databaseService.getUnsyncedModifications();
  }

  Future<bool> hasUnsyncedChanges() async {
    final modifications = await getUnsyncedModifications();
    return modifications.isNotEmpty;
  }

  // Cache management
  Future<void> clearCache() async {
    await _databaseService.clearCache();
  }

  Future<void> dispose() async {
    await _databaseService.close();
  }

  // Get roles
  Future<List<Role>> getRoles() async {
    if (await isOnline) {
      return await _apiService.getRoles();
    } else {
      throw Exception('Cannot get roles offline');
    }
  }
}
