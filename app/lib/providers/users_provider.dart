import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../services/data_service.dart';

enum UsersStatus { initial, loading, loaded, error }

class UsersProvider extends ChangeNotifier {
  final DataService _dataService;

  UsersStatus _status = UsersStatus.initial;
  List<User> _users = [];
  List<Role> _roles = [];
  User? _selectedUser;
  String? _errorMessage;
  int _totalUsers = 0;
  int _currentPage = 1;
  final int _limit = 20;
  String _searchQuery = '';
  String _selectedRole = '';
  bool _hasUnsyncedChanges = false;

  UsersProvider(this._dataService);

  // Getters
  UsersStatus get status => _status;
  List<User> get users => _users;
  List<Role> get roles => _roles;
  User? get selectedUser => _selectedUser;
  String? get errorMessage => _errorMessage;
  int get totalUsers => _totalUsers;
  int get currentPage => _currentPage;
  int get limit => _limit;
  String get searchQuery => _searchQuery;
  String get selectedRole => _selectedRole;
  bool get hasUnsyncedChanges => _hasUnsyncedChanges;
  bool get isLoading => _status == UsersStatus.loading;
  bool get hasMorePages => (_currentPage * _limit) < _totalUsers;

  Future<void> loadUsers({
    int page = 1,
    String search = '',
    String role = '',
    bool append = false,
  }) async {
    if (!append) {
      _status = UsersStatus.loading;
      _users = [];
    }
    
    _errorMessage = null;
    _searchQuery = search;
    _selectedRole = role;
    _currentPage = page;
    notifyListeners();

    try {
      final response = await _dataService.getUsers(
        page: page,
        limit: _limit,
        search: search,
        role: role,
      );

      if (append) {
        _users.addAll(response.users);
      } else {
        _users = response.users;
      }
      
      _totalUsers = response.total;
      _status = UsersStatus.loaded;
    } catch (e) {
      _status = UsersStatus.error;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }

    notifyListeners();
  }

  Future<void> loadMoreUsers() async {
    if (!hasMorePages || isLoading) return;
    await loadUsers(
      page: _currentPage + 1,
      search: _searchQuery,
      role: _selectedRole,
      append: true,
    );
  }

  Future<void> refreshUsers() async {
    await loadUsers(
      page: 1,
      search: _searchQuery,
      role: _selectedRole,
    );
  }

  Future<void> searchUsers(String query) async {
    await loadUsers(
      page: 1,
      search: query,
      role: _selectedRole,
    );
  }

  Future<void> filterByRole(String role) async {
    await loadUsers(
      page: 1,
      search: _searchQuery,
      role: role,
    );
  }

  Future<void> loadUser(String identifier) async {
    try {
      _selectedUser = await _dataService.getUser(identifier);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      await _dataService.createUser(userData);
      await refreshUsers(); // Refresh the list
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> userData) async {
    try {
      await _dataService.updateUser(userId, userData);
      
      // Update the user in the local list
      final userIndex = _users.indexWhere((user) => user.id == userId);
      if (userIndex != -1) {
        // Create a new user object with updated data
        final updatedUser = _users[userIndex].copyWith(
          firstName: userData['firstName'] ?? _users[userIndex].firstName,
          lastName: userData['lastName'] ?? _users[userIndex].lastName,
          email: userData['email'] ?? _users[userIndex].email,
          phoneNumber: userData['phoneNumber'] ?? _users[userIndex].phoneNumber,
          department: userData['department'] ?? _users[userIndex].department,
          position: userData['position'] ?? _users[userIndex].position,
          role: userData['role'] ?? _users[userIndex].role,
          isActive: userData['isActive'] ?? _users[userIndex].isActive,
          updatedAt: DateTime.now(),
        );
        
        _users[userIndex] = updatedUser;
      }

      // Update selected user if it's the same
      if (_selectedUser?.id == userId) {
        _selectedUser = _users.firstWhere((user) => user.id == userId);
      }

      await checkUnsyncedChanges();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _dataService.deleteUser(userId);
      _users.removeWhere((user) => user.id == userId);
      if (_selectedUser?.id == userId) {
        _selectedUser = null;
      }
      _totalUsers--;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> loadRoles() async {
    try {
      _roles = await _dataService.getRoles();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading roles: $e');
    }
  }

  Future<void> syncData() async {
    try {
      await _dataService.syncData();
      await checkUnsyncedChanges();
      await refreshUsers();
    } catch (e) {
      _errorMessage = 'Sync failed: ${e.toString().replaceFirst('Exception: ', '')}';
      notifyListeners();
    }
  }

  Future<void> checkUnsyncedChanges() async {
    try {
      _hasUnsyncedChanges = await _dataService.hasUnsyncedChanges();
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking unsynced changes: $e');
    }
  }

  void clearSelectedUser() {
    _selectedUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearUsers() {
    _users = [];
    _selectedUser = null;
    _totalUsers = 0;
    _currentPage = 1;
    _searchQuery = '';
    _selectedRole = '';
    _status = UsersStatus.initial;
    notifyListeners();
  }
}
