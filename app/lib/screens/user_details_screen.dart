import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class UserDetailsScreen extends StatefulWidget {
  final String userId;

  const UserDetailsScreen({super.key, required this.userId});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _departmentController;
  late TextEditingController _positionController;
  
  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUser();
  }
  
  void _initializeControllers() {
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _departmentController = TextEditingController();
    _positionController = TextEditingController();
  }
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    await usersProvider.loadUser(widget.userId);
    
    final user = usersProvider.selectedUser;
    if (user != null) {
      _firstNameController.text = user.firstName ?? '';
      _lastNameController.text = user.lastName ?? '';
      _emailController.text = user.email;
      _phoneController.text = user.phoneNumber ?? '';
      _departmentController.text = user.department ?? '';
      _positionController.text = user.position ?? '';
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final usersProvider = Provider.of<UsersProvider>(context, listen: false);
    final user = usersProvider.selectedUser;
    
    if (user == null) return;

    final updates = <String, dynamic>{
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'department': _departmentController.text.trim(),
      'position': _positionController.text.trim(),
    };

    final success = await usersProvider.updateUser(user.id, updates);
    
    if (success && mounted) {
      setState(() {
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} modifié avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UsersProvider, AuthProvider>(
      builder: (context, usersProvider, authProvider, child) {
        final user = usersProvider.selectedUser;
        final currentUser = authProvider.currentUser;
        final canEdit = currentUser?.hasEditPermissions == true || 
                       currentUser?.id == user?.id;

        if (_isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chargement...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Utilisateur')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Utilisateur non trouvé',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(user.fullName),
            actions: [
              if (canEdit && !_isEditing)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                ),
              if (_isEditing) ...[
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      // Reset form
                      _loadUser();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveChanges,
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _isEditing ? _buildEditForm(user) : _buildViewMode(user),
          ),
        );
      },
    );
  }

  Widget _buildViewMode(User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile header
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName.substring(0, 1).toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${user.username}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user.role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(user.role),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!user.isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'INACTIF',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // User information
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informations personnelles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                _buildInfoRow('Email', user.email),
                if (user.phoneNumber?.isNotEmpty == true)
                  _buildInfoRow('Téléphone', user.phoneNumber!),
                if (user.department?.isNotEmpty == true)
                  _buildInfoRow('Département', user.department!),
                if (user.position?.isNotEmpty == true)
                  _buildInfoRow('Poste', user.position!),
                
                const Divider(height: 24),
                
                _buildInfoRow('ID Utilisateur', user.id),
                _buildInfoRow('Compte créé le', 
                  DateFormat('dd/MM/yyyy à HH:mm').format(user.createdAt)),
                
                if (user.lastLogin != null)
                  _buildInfoRow('Dernière connexion',
                    DateFormat('dd/MM/yyyy à HH:mm').format(user.lastLogin!)),

                if (user.updatedAt != null)
                  _buildInfoRow('Dernière modification',
                    DateFormat('dd/MM/yyyy à HH:mm').format(user.updatedAt!)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm(User user) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Modifier les informations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'Prénom',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty == true) {
                              return 'Le prénom est requis';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty == true) {
                              return 'Le nom est requis';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value?.trim().isEmpty == true) {
                        return 'L\'email est requis';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value!)) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _departmentController,
                    decoration: const InputDecoration(
                      labelText: 'Département',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _positionController,
                    decoration: const InputDecoration(
                      labelText: 'Poste',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveChanges,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Enregistrer les modifications'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'manager':
        return Colors.blue;
      case 'scanner':
        return Colors.green;
      case 'user':
      default:
        return Colors.grey;
    }
  }
}
