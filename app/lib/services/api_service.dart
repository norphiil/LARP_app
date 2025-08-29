import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../models/api_models.dart';

class ApiService {
  static const String tokenKey = 'auth_token';
  
  String? _token;
  
  String? get token => _token;
  
  // Headers with authentication
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // Initialize token from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(tokenKey);
  }

  // Save token to storage
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    _token = token;
  }

  // Clear token from storage
  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    _token = null;
  }

  // Check if user is authenticated
  bool get isAuthenticated => _token != null;

  // Handle HTTP errors
  void _handleError(http.Response response) {
    if (response.statusCode == 401) {
      _clearToken();
      throw Exception('Authentication required');
    }

    // Gestion spéciale pour 404 page not found (souvent HTML)
    if (response.statusCode == 404 &&
        response.body.trim().toLowerCase().contains('page not found')) {
      throw Exception('Erreur de connexion au serveur. Veuillez réessayer plus tard.');
    }

    try {
      final body = jsonDecode(response.body);
      final error = body['error'] ?? 'Unknown error';
      throw Exception(error);
    } catch (e) {
      // Si la réponse n'est pas du JSON (ex: HTML d'erreur)
      throw Exception('Erreur de connexion au serveur. Veuillez réessayer plus tard.');
    }
  }

  // Authentication
  Future<AuthResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(AppConfig.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final authResponse = AuthResponse.fromJson(jsonDecode(response.body));
      await _saveToken(authResponse.token);
      return authResponse;
    } else {
      _handleError(response);
      throw Exception('Login failed');
    }
  }

  // Logout
  Future<void> logout() async {
    await _clearToken();
  }

  // Get current user profile
  Future<User> getCurrentUser() async {
    final response = await http.get(
      Uri.parse(AppConfig.profileUrl),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to get user profile');
    }
  }

  // Get users list
  Future<UsersListResponse> getUsers({
    int page = 1,
    int limit = 20,
    String search = '',
    String role = '',
  }) async {
    final uri = Uri.parse(AppConfig.usersUrl).replace(queryParameters: {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search.isNotEmpty) 'search': search,
      if (role.isNotEmpty) 'role': role,
    });

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return UsersListResponse.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to get users');
    }
  }

  // Get user by ID or QR code
  Future<User> getUser(String identifier) async {
    final response = await http.get(
      Uri.parse(AppConfig.userUrl(identifier)),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    } else {
      _handleError(response);
      throw Exception('Failed to get user');
    }
  }

  // Create user
  Future<String> createUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse(AppConfig.usersUrl),
      headers: _headers,
      body: jsonEncode(userData),
    );

    if (response.statusCode == 201) {
      final body = jsonDecode(response.body);
      return body['userId'] as String;
    } else {
      _handleError(response);
      throw Exception('Failed to create user');
    }
  }

  // Update user
  Future<void> updateUser(String userId, Map<String, dynamic> userData) async {
    final response = await http.put(
      Uri.parse(AppConfig.userUrl(userId)),
      headers: _headers,
      body: jsonEncode(userData),
    );

    if (response.statusCode != 200) {
      _handleError(response);
      throw Exception('Failed to update user');
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse(AppConfig.userUrl(userId)),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      _handleError(response);
      throw Exception('Failed to delete user');
    }
  }

  // Get roles
  Future<List<Role>> getRoles() async {
    final response = await http.get(
      Uri.parse(AppConfig.rolesUrl),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> rolesJson = jsonDecode(response.body);
      return rolesJson.map((json) => Role.fromJson(json)).toList();
    } else {
      _handleError(response);
      throw Exception('Failed to get roles');
    }
  }

  // Get unsynced modifications
  Future<List<UserModification>> getUnsyncedModifications() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/api/sync/modifications'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> modificationsJson = jsonDecode(response.body);
      return modificationsJson.map((json) => UserModification.fromJson(json)).toList();
    } else {
      _handleError(response);
      throw Exception('Failed to get modifications');
    }
  }

  // Mark modification as synced
  Future<void> markModificationSynced(String modificationId) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/api/sync/modifications/$modificationId/sync'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      _handleError(response);
      throw Exception('Failed to mark modification as synced');
    }
  }

  // Health check
  Future<bool> isServerHealthy() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/api/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
