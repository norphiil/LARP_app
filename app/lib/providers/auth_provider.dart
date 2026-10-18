import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/user.dart';
import '../services/data_service.dart';

enum AuthStatus { 
  initial, 
  loading, 
  authenticated, 
  unauthenticated, 
  error 
}

class AuthProvider extends ChangeNotifier {
  final DataService _dataService;
  
  AuthStatus _status = AuthStatus.initial;
  User? _currentUser;
  String? _errorMessage;

  AuthProvider(this._dataService);

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;

  Future<void> initialize() async {
    _status = AuthStatus.loading;
    
    try {
      _currentUser = await _dataService.getCurrentUser();
      _status = AuthStatus.authenticated;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
    
    // Utiliser SchedulerBinding pour notifier après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await _dataService.login(username, password);
      _currentUser = authResponse.user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Register initial admin via backend and set authenticated state if successful
  Future<bool> registerInitial(String username, String email, String password, {String? firstName, String? lastName}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
  await _dataService.registerInitialAdmin(username, email, password, firstName: firstName, lastName: lastName);
      // After registering initial admin, load current user
      _currentUser = await _dataService.getCurrentUser();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _dataService.logout();
    } catch (e) {
      // Even if logout fails, we still want to clear local state
      debugPrint('Logout error: $e');
    }

    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_status != AuthStatus.authenticated) return;

    try {
      _currentUser = await _dataService.getCurrentUser();
      notifyListeners();
    } catch (e) {
      debugPrint('Refresh user error: $e');
      // Don't change auth status if refresh fails
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Probe backend to know if initial admin registration is allowed
  Future<bool> canRegisterInitial() async {
    try {
      return await _dataService.canRegisterInitial();
    } catch (e) {
      debugPrint('canRegisterInitial probe error: $e');
      return false;
    }
  }
}
