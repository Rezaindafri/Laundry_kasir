import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/user_management_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  final UserRole? initialCreateRole;

  const UserManagementScreen({this.initialCreateRole, super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  var _openedRequestedForm = false;
  var _superOwnerSection = UserRole.owner;

  @override
  void initState() {
    super.initState();
    if (widget.initialCreateRole != null) {
      _superOwnerSection = widget.initialCreateRole!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _openedRequestedForm ||
          widget.initialCreateRole == null) {
        return;
      }
      final current = ref.read(sessionProvider).valueOrNull;
      if (current == null || !current.role.canManageUsers) return;
      _openedRequestedForm = true;
      _showUserForm(
        context,
        ref,
        current.role,
        initialRole: widget.initialCreateRole,
        passwordMinLength:
            ref.read(accountPasswordMinLengthProvider).valueOrNull ?? 6,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(sessionProvider).valueOrNull;
    final users = ref.watch(managedUsersProvider);
    final passwordMinLength =
        ref.watch(accountPasswordMinLengthProvider).valueOrNull ?? 6;
    if (current == null || !current.role.canManageUsers) {
      return const Scaffold(
        body: Center(child: Text('Anda tidak memiliki akses.')),
      );
    }

    final items = users.valueOrNull ?? const <UserEntity>[];
    final ownerNames = {
      for (final owner in items.where((item) => item.role == UserRole.owner))
        owner.id: owner.name,
    };

    return Scaffold(
      drawer: AppNavigationDrawer(user: current),
      appBar: AppBar(
        title: Text(
          current.role == UserRole.superOwner
              ? 'Kelola Struktur Akun'
              : 'Manajemen User',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(
          context,
          ref,
          current.role,
          initialRole: current.role == UserRole.superOwner
              ? _superOwnerSection
              : null,
          passwordMinLength: passwordMinLength,
        ),
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(current.role == UserRole.superOwner
            ? _superOwnerSection == UserRole.owner
                ? 'Tambah Owner'
                : 'Tambah Kasir'
            : 'Tambah'),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          error: error,
          onRetry: () => ref.read(managedUsersProvider.notifier).refresh(),
        ),
        data: (users) {
          final visibleUsers = current.role == UserRole.superOwner
              ? users
                  .where((user) => user.role == _superOwnerSection)
                  .toList(growable: false)
              : users;
          final list = ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: visibleUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final user = visibleUsers[index];
            final editable = user.role != UserRole.superOwner ||
                current.role == UserRole.superOwner;
            final ownerLabel = current.role == UserRole.superOwner &&
                    user.role == UserRole.kasir
                ? ' • Owner: ${ownerNames[user.ownerId] ?? 'Belum ditetapkan'}'
                : '';
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(user.name.substring(0, 1).toUpperCase()),
                ),
                title: Text(user.name),
                subtitle:
                    Text('@${user.username} • ${user.role.label}$ownerLabel'),
                trailing: Switch(
                  value: user.isActive,
                  onChanged: !editable
                      ? null
                      : (_) => _toggleStatus(context, ref, user),
                ),
                onTap: !editable
                    ? null
                    : () => _showUserForm(
                          context,
                          ref,
                          current.role,
                          user: user,
                        ),
              ),
            );
            },
          );

          if (current.role != UserRole.superOwner) return list;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.owner,
                      icon: Icon(Icons.business_outlined),
                      label: Text('Owner'),
                    ),
                    ButtonSegment(
                      value: UserRole.kasir,
                      icon: Icon(Icons.people_outline),
                      label: Text('Kasir'),
                    ),
                  ],
                  selected: {_superOwnerSection},
                  onSelectionChanged: (selection) => setState(
                    () => _superOwnerSection = selection.first,
                  ),
                ),
              ),
              Expanded(child: list),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _showUserForm(
  BuildContext context,
  WidgetRef ref,
  UserRole actorRole, {
  UserEntity? user,
  UserRole? initialRole,
  int passwordMinLength = 6,
}) async {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: user?.name);
  final username = TextEditingController(text: user?.username);
  final password = TextEditingController();
  final managedUsers =
      ref.read(managedUsersProvider).valueOrNull ?? const <UserEntity>[];
  final owners = managedUsers
      .where((item) => item.role == UserRole.owner)
      .toList(growable: false);
  var role = user?.role ?? initialRole ?? UserRole.kasir;
  var ownerId = user?.ownerId;
  final roles = user?.role == UserRole.superOwner
      ? [UserRole.superOwner]
      : actorRole == UserRole.superOwner
          ? [UserRole.owner, UserRole.kasir]
          : [UserRole.kasir];

  if (!roles.contains(role)) role = roles.first;

  final result = await showModalBottomSheet<_UserFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user == null ? 'Akun Baru' : 'Ubah Akun',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (value) =>
                      Validators.required(value, field: 'Nama'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) =>
                      Validators.required(value, field: 'Username'),
                ),
                if (user == null) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) =>
                        value == null || value.length < passwordMinLength
                        ? 'Password minimal $passwordMinLength karakter'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: roles
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: user?.role == UserRole.superOwner
                      ? null
                      : (value) => setState(() {
                            role = value!;
                            if (role != UserRole.kasir) ownerId = null;
                          }),
                ),
                if (actorRole == UserRole.superOwner &&
                    role == UserRole.kasir) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: owners.any(
                            (owner) => owner.id == ownerId && owner.isActive)
                        ? ownerId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Owner penanggung jawab',
                    ),
                    items: owners
                        .where((owner) => owner.isActive)
                        .map(
                          (owner) => DropdownMenuItem(
                            value: owner.id,
                            child: Text('${owner.name} (@${owner.username})'),
                          ),
                        )
                        .toList(),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Pilih owner penanggung jawab'
                        : null,
                    onChanged: (value) => setState(() => ownerId = value),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(
                      sheetContext,
                      _UserFormResult(
                        user: UserEntity(
                          id: user?.id ?? '',
                          name: name.text.trim(),
                          username: username.text.trim(),
                          role: user?.role == UserRole.superOwner
                              ? UserRole.superOwner
                              : role,
                          ownerId: role == UserRole.kasir &&
                                  actorRole == UserRole.superOwner
                              ? ownerId
                              : user?.ownerId,
                          isActive: user?.isActive ?? true,
                          createdAt: user?.createdAt ?? DateTime.now(),
                        ),
                        password: password.text,
                      ),
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  if (result != null) {
    final saved = await ref
        .read(managedUsersProvider.notifier)
        .saveUser(result.user, password: result.password);
    if (context.mounted) {
      saved.when(
        success: (_) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              user == null
                  ? 'Akun pengguna berhasil dibuat.'
                  : 'Akun pengguna berhasil diperbarui.',
            ),
          ),
        ),
        error: (failure) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        ),
      );
    }
  }
  name.dispose();
  username.dispose();
  password.dispose();
}

Future<void> _toggleStatus(
  BuildContext context,
  WidgetRef ref,
  UserEntity user,
) async {
  final result =
      await ref.read(managedUsersProvider.notifier).toggleUserStatus(user.id);
  if (!context.mounted) return;
  result.when(
    success: (_) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          user.isActive
              ? 'Akun berhasil dinonaktifkan.'
              : 'Akun berhasil diaktifkan.',
        ),
      ),
    ),
    error: (failure) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message)),
    ),
  );
}

class _UserFormResult {
  final UserEntity user;
  final String password;

  const _UserFormResult({required this.user, required this.password});
}

class _LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Gagal memuat pengguna: $error',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
}
