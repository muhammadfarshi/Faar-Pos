import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../domain/entities/user_entity.dart';
import '../../providers/catalog_provider.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  void _openUserDialog([UserEntity? user]) {
    final nameCtrl = TextEditingController(text: user?.fullName ?? '');
    final emailCtrl = TextEditingController(text: user?.email ?? '');
    final pinCtrl = TextEditingController(text: '0000');
    UserRole selectedRole = user?.role ?? UserRole.cashier;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Add Staff Member' : 'Edit Staff Member'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email Address *'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role *'),
                    items: const [
                      DropdownMenuItem(value: UserRole.cashier, child: Text('Cashier (POS Sales only)')),
                      DropdownMenuItem(value: UserRole.manager, child: Text('Manager (Reports & Inventory)')),
                      DropdownMenuItem(value: UserRole.branchAdmin, child: Text('Branch Admin (Full Store Access)')),
                      DropdownMenuItem(value: UserRole.orgAdmin, child: Text('Org Admin (Superuser)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pinCtrl,
                    decoration: const InputDecoration(labelText: 'Quick PIN (4 Digits)'),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final newUser = UserEntity(
                    id: user?.id ?? 0,
                    orgId: 1,
                    branchId: 1,
                    fullName: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    role: selectedRole,
                    isActive: true,
                  );

                  AppDatabase.instance.upsertUser(newUser, pinCode: pinCtrl.text.trim());
                  Navigator.of(ctx).pop();
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Saved user "${newUser.fullName}"'),
                      backgroundColor: FaarPosTheme.kSuccess,
                    ),
                  );
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteUser(UserEntity u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text('Are you sure you want to deactivate ${u.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FaarPosTheme.kDanger),
            onPressed: () {
              AppDatabase.instance.deleteUser(u.id);
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.orgAdmin: return FaarPosTheme.kDanger;
      case UserRole.branchAdmin: return FaarPosTheme.kPrimary;
      case UserRole.manager: return FaarPosTheme.kWarning;
      default: return FaarPosTheme.kSuccess;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(databaseChangeListenerProvider);
    final users = AppDatabase.instance.getAllUsers();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUserDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
      ),
      body: users.isEmpty
          ? const Center(child: Text('No users found'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final u = users[index];
                final initials = u.fullName.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join();

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _roleColor(u.role).withValues(alpha: 0.15),
                      child: Text(
                        initials.toUpperCase(),
                        style: TextStyle(
                          color: _roleColor(u.role),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(u.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            u.role.name.toUpperCase(),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _roleColor(u.role)),
                          ),
                          backgroundColor: _roleColor(u.role).withValues(alpha: 0.1),
                          side: BorderSide.none,
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _openUserDialog(u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: FaarPosTheme.kDanger),
                          onPressed: () => _deleteUser(u),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
