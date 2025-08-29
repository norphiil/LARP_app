import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/user_card.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usersProvider = Provider.of<UsersProvider>(context, listen: false);
      usersProvider.refreshUsers();
      usersProvider.loadRoles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final usersProvider = Provider.of<UsersProvider>(context, listen: false);
              usersProvider.refreshUsers();
            },
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.push('/create-user'),
            tooltip: 'Créer un utilisateur',
          ),
        ],
      ),
      body: Consumer2<UsersProvider, AuthProvider>(
        builder: (context, usersProvider, authProvider, child) {
          if (usersProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (usersProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Erreur',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    usersProvider.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => usersProvider.refreshUsers(),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final users = usersProvider.users;
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun utilisateur',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Commencez par créer votre premier utilisateur',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/create-user'),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Créer un utilisateur'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await usersProvider.refreshUsers();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: UserCard(user: user),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final currentUser = authProvider.currentUser;
          final canCreateUsers = currentUser?.role == 'admin' || 
                                currentUser?.role == 'manager';
          
          if (!canCreateUsers) return const SizedBox.shrink();
          
          return FloatingActionButton(
            onPressed: () => context.push('/create-user'),
            tooltip: 'Créer un utilisateur',
            child: const Icon(Icons.person_add),
          );
        },
      ),
    );
  }
}
