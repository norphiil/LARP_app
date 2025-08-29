import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'config/app_config.dart';
import 'services/api_service.dart';
import 'services/database_service.dart';
import 'services/data_service.dart';
import 'providers/auth_provider.dart';
import 'providers/users_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/user_details_screen.dart';
import 'screens/users_screen.dart';
import 'screens/create_user_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize configuration
  await AppConfig.initialize();
  
  // Initialize database factory (required for desktop platforms)
  await DatabaseService.initializeDatabaseFactory();
  
  // Initialize services
  final apiService = ApiService();
  await apiService.init();
  
  final databaseService = DatabaseService();
  final dataService = DataService(
    apiService: apiService,
    databaseService: databaseService,
  );

  runApp(MyApp(dataService: dataService));
}

class MyApp extends StatelessWidget {
  final DataService dataService;

  const MyApp({super.key, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => AuthProvider(dataService),
        ),
        ChangeNotifierProvider(
          create: (context) => UsersProvider(dataService),
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return MaterialApp.router(
            title: 'User Management',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: const CardThemeData(
                elevation: 2,
              ),
            ),
            routerConfig: _createRouter(authProvider),
          );
        },
      ),
    );
  }

  GoRouter _createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login';

        // Initialize auth state if needed
        if (authProvider.status == AuthStatus.initial) {
          authProvider.initialize();
          return null;
        }

        // Redirect to login if not authenticated
        if (!isAuthenticated && !isLoggingIn) {
          return '/login';
        }

        // Redirect to home if authenticated and trying to access login
        if (isAuthenticated && isLoggingIn) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/qr-scanner',
          builder: (context, state) => const QRScannerScreen(),
        ),
        GoRoute(
          path: '/users',
          builder: (context, state) => const UsersScreen(),
        ),
        GoRoute(
          path: '/create-user',
          builder: (context, state) => const CreateUserScreen(),
        ),
        GoRoute(
          path: '/edit-user/:userId',
          builder: (context, state) => const HomeScreen(), // Temporary redirect
        ),
        GoRoute(
          path: '/edit-profile',
          builder: (context, state) => const ProfileScreen(), // Temporary redirect
        ),
        GoRoute(
          path: '/user-qr/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserDetailsScreen(userId: userId); // Temporary redirect
          },
        ),
        GoRoute(
          path: '/user-details/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserDetailsScreen(userId: userId);
          },
        ),
      ],
    );
  }
}
