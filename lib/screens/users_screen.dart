import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/database_services.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final DatabaseService _db = DatabaseService();
  List<AppUser> _users = [];
  StreamSubscription<List<AppUser>>? _sub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _sub = _db.watchUsers().listen(
      (users) {
        if (!mounted) return;
        setState(() {
          _users = users;
          _loading = false;
        });
      },
      onError: (e) {
        debugPrint('Users stream error: $e');
        if (!mounted) return;
        setState(() => _loading = false);
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Director':
        return Colors.red;
      case 'Co-Director':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('No users found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return InkWell(
                      onTap: () => _showRoleForm(user),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  cs.primary.withValues(alpha: 0.15),
                              child: Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.6)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _roleColor(user.role),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user.role,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right,
                                color: cs.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _showRoleForm(AppUser user) async {
    final auth = context.read<AuthService>();

    if (!auth.hasPermission('Co-Director')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Only Directors and Co-Directors can change roles')),
      );
      return;
    }

    if (auth.userRole == 'Co-Director' && user.role == 'Director') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Co-Directors cannot change Director roles')),
      );
      return;
    }

    var selectedRole = user.role;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 20),
                  for (final role in const [
                    'Director',
                    'Co-Director',
                    'Manager',
                  ])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(role),
                      trailing: Icon(
                        selectedRole == role
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: selectedRole == role
                            ? const Color(0xFF2196F3)
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3),
                      ),
                      onTap: () => setSheetState(() => selectedRole = role),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Update Role'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (shouldSave != true || selectedRole == user.role) return;

    try {
      await auth.changeUserRole(user.id, selectedRole);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User role updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: $e')),
      );
    }
  }
}
