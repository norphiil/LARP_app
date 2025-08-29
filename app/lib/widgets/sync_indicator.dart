import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/users_provider.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UsersProvider>(
      builder: (context, usersProvider, child) {
        if (!usersProvider.hasUnsyncedChanges) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sync_problem,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Non sync',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
