import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon profil'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  context.push('/edit-profile');
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile header
                _buildProfileHeader(user),
                const SizedBox(height: 24),

                // QR Code section
                _buildQRCodeSection(user),
                const SizedBox(height: 24),

                // User information
                _buildUserInfo(user),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(User user) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
              child: user.profilePicture != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image.network(
                        user.profilePicture!,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                            _buildDefaultAvatar(user),
                      ),
                    )
                  : _buildDefaultAvatar(user),
            ),
            const SizedBox(height: 16),

            // Name and username
            Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
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

            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _getRoleColor(user.role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                user.role.toUpperCase(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(user.role),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(User user) {
    return Text(
      user.fullName.isNotEmpty
          ? user.fullName.substring(0, 1).toUpperCase()
          : 'U',
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.bold,
        color: _getRoleColor(user.role),
      ),
    );
  }

  Widget _buildQRCodeSection(User user) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Mon QR Code',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: user.qrCodeData ?? user.id,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  
                  // User ID below QR code
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ID: ${user.id}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Scannez ce code pour identifier cet utilisateur',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(User user) {
    return Card(
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
            if (user.phoneNumber != null)
              _buildInfoRow('Téléphone', user.phoneNumber!),
            if (user.department != null)
              _buildInfoRow('Département', user.department!),
            if (user.position != null)
              _buildInfoRow('Poste', user.position!),
            
            const Divider(height: 24),
            
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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
