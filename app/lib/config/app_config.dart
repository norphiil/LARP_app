import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000';
  static String get appName => dotenv.env['APP_NAME'] ?? 'Flutter User Management';
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '30000') ?? 30000;
  
  // URLs des endpoints API
  static String get loginUrl => '$apiBaseUrl/api/auth/login';
  static String get refreshTokenUrl => '$apiBaseUrl/api/refresh-token';
  static String get usersUrl => '$apiBaseUrl/api/users';
  static String get rolesUrl => '$apiBaseUrl/api/roles';
  static String get profileUrl => '$apiBaseUrl/api/auth/profile';
  
  // Méthodes utilitaires
  static String userUrl(String userId) => '$apiBaseUrl/api/users/$userId';
  static String userQrUrl(String userId) => '$apiBaseUrl/api/users/$userId/qr';
  
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
  }
}
