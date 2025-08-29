import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/users_provider.dart';
import '../models/user.dart';
import '../widgets/user_card.dart';
import '../widgets/sync_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    await usersProvider.loadUsers();
    await usersProvider.loadRoles();
    await usersProvider.checkUnsyncedChanges();
  }

  void _showQRScanner() {
    context.push('/qr-scanner');
  }

  void _showUserProfile() {
    context.push('/profile');
  }

  void _showUsersList() {
    context.push('/users');
  }

  void _showCreateUser() {
    context.push('/create-user');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UsersProvider>(
      builder: (context, authProvider, usersProvider, child) {
        final user = authProvider.currentUser;
        
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('User Management'),
            actions: [
              // Sync indicator
              const SyncIndicator(),
              const SizedBox(width: 8),
              
              // Profile menu
              PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.fullName.isNotEmpty 
                        ? user.fullName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'profile':
                      _showUserProfile();
                      break;
                    case 'sync':
                      usersProvider.syncData();
                      break;
                    case 'logout':
                      authProvider.logout();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: const Row(
                      children: [
                        Icon(Icons.person),
                        SizedBox(width: 8),
                        Text('Mon profil'),
                      ],
                    ),
                  ),
                  if (usersProvider.hasUnsyncedChanges)
                    PopupMenuItem(
                      value: 'sync',
                      child: const Row(
                        children: [
                          Icon(Icons.sync, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Synchroniser'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Déconnexion'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Welcome section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour ${user.fullName}!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rôle: ${user.role.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Quick actions grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      // Mon profil
                      _buildQuickAction(
                        icon: Icons.person,
                        title: 'Mon profil',
                        subtitle: 'Voir mes informations',
                        color: Colors.blue,
                        onTap: _showUserProfile,
                      ),

                      // QR Code Scanner (if has permission)
                      if (user.canScanQR)
                        _buildQuickAction(
                          icon: Icons.qr_code_scanner,
                          title: 'Scanner QR',
                          subtitle: 'Lire un QR code',
                          color: Colors.green,
                          onTap: _showQRScanner,
                        ),

                      // Users management (if has permission)
                      if (user.hasEditPermissions)
                        _buildQuickAction(
                          icon: Icons.people,
                          title: 'Utilisateurs',
                          subtitle: 'Gérer les utilisateurs',
                          color: Colors.purple,
                          onTap: _showUsersList,
                        ),

                      // Create user (if has permission)
                      if (user.canCreateUsers)
                        _buildQuickAction(
                          icon: Icons.person_add,
                          title: 'Nouvel utilisateur',
                          subtitle: 'Créer un compte',
                          color: Colors.orange,
                          onTap: _showCreateUser,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
