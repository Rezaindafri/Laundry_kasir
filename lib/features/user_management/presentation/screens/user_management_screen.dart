import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/user_management_providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sessionProvider).valueOrNull;
    final users = ref.watch(managedUsersProvider);
    if (current == null || !current.role.canManageUsers) {
      return const Scaffold(
          body: Center(child: Text('Anda tidak memiliki akses.')),);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen User')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(context, ref, current.role),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tambah'),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Gagal memuat user: $error')),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final user = items[index];
            final editable = user.role != UserRole.superOwner ||
                current.role == UserRole.superOwner;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                    child: Text(user.name.substring(0, 1).toUpperCase()),),
                title: Text(user.name),
                subtitle: Text('@${user.username} • ${user.role.label}'),
                trailing: Switch(
                  value: user.isActive,
                  onChanged: !editable
                      ? null
                      : (value) =>
                          ref.read(managedUsersProvider.notifier).saveUser(
                                UserEntity(
                                  id: user.id,
                                  name: user.name,
                                  username: user.username,
                                  role: user.role,
                                  isActive: value,
                                  createdAt: user.createdAt,
                                ),
                              ),
                ),
                onTap: () =>
                    _showUserForm(context, ref, current.role, user: user),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showUserForm(
    BuildContext context,
    WidgetRef ref,
    UserRole actorRole, {
    UserEntity? user,
  }) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: user?.name);
    final username = TextEditingController(text: user?.username);
    var role = user?.role ?? UserRole.kasir;
    final roles = actorRole == UserRole.superOwner
        ? [UserRole.owner, UserRole.kasir]
        : [UserRole.kasir];
    final result = await showModalBottomSheet<UserEntity>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, 24 + MediaQuery.viewInsetsOf(sheetContext).bottom,),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user == null ? 'Akun Baru' : 'Ubah Akun',
                    style: Theme.of(sheetContext).textTheme.titleLarge,),
                const SizedBox(height: 20),
                TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nama'),
                    validator: (value) =>
                        Validators.required(value, field: 'Nama'),),
                const SizedBox(height: 12),
                TextFormField(
                    controller: username,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: (value) =>
                        Validators.required(value, field: 'Username'),),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles
                      .map((item) => DropdownMenuItem(
                          value: item, child: Text(item.label),),)
                      .toList(),
                  onChanged: user?.role == UserRole.superOwner
                      ? null
                      : (value) => setState(() => role = value!),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(
                        sheetContext,
                        UserEntity(
                            id: user?.id ?? '',
                            name: name.text.trim(),
                            username: username.text.trim(),
                            role: user?.role == UserRole.superOwner
                                ? UserRole.superOwner
                                : role,
                            isActive: user?.isActive ?? true,
                            createdAt: user?.createdAt ?? DateTime.now(),),);
                  },
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      await ref.read(managedUsersProvider.notifier).saveUser(result);
    }
    name.dispose();
    username.dispose();
  }
}
