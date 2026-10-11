import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/navigation_write_guard.dart';
import '../../../../core/widgets/safe_modal_sheet.dart';
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
      if (!isCurrentPage(context) ||
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

    return NavigationWriteGuard(
        child: Scaffold(
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
          initialRole:
              current.role == UserRole.superOwner ? _superOwnerSection : null,
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
          final emptyMessage = current.role == UserRole.superOwner
              ? _superOwnerSection == UserRole.owner
                  ? 'Data owner saat ini belum tersedia.'
                  : 'Data kasir saat ini belum tersedia.'
              : 'Belum ada kasir di bawah Owner ini.';
          final list = visibleUsers.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 150),
                    const Icon(Icons.people_outline,
                        size: 48, color: Colors.blueGrey),
                    const SizedBox(height: 12),
                    Text(emptyMessage, textAlign: TextAlign.center),
                  ],
                )
              : ListView.separated(
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
                          backgroundColor: AppColors.profileAvatar,
                          foregroundColor: AppColors.profileAvatarText,
                          child: Text(
                            user.name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.profileAvatarText),
                          ),
                        ),
                        title: Text(user.name),
                        subtitle: Text(
                            '@${user.username} • ${user.role.label}$ownerLabel'),
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
                                  passwordMinLength: passwordMinLength,
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
    ));
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

  final result = await showSafeModalBottomSheet<_UserFormResult>(
    context: context,
    isScrollControlled: true,
    controllers: [name, username, password],
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
                  enabled: user == null,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    helperText: user == null
                        ? null
                        : 'Ubah melalui Kelola kredensial dengan verifikasi owner.',
                  ),
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
                if (user != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Tunggu bottom sheet ini selesai tertutup sebelum
                      // membuka sheet kredensial. Dua sheet yang bertumpuk
                      // dapat meninggalkan dependents widget yang belum lepas.
                      Navigator.pop(
                        sheetContext,
                        _UserFormResult(
                          user: user,
                          password: '',
                          openCredentials: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.key_outlined),
                    label: const Text('Kelola kredensial'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  if (!isCurrentPage(context)) return;
  if (result != null && result.openCredentials && user != null) {
    if (context.mounted) {
      await _showCredentialEditor(
        context,
        ref,
        user,
        managerRole: actorRole,
        passwordMinLength: passwordMinLength,
      );
    }
    return;
  }
  if (result != null) {
    final saved = await withNavigationWriteLock(
        ref,
        () => ref
            .read(managedUsersProvider.notifier)
            .saveUser(result.user, password: result.password));
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
}

Future<void> _toggleStatus(
  BuildContext context,
  WidgetRef ref,
  UserEntity user,
) async {
  final result = await withNavigationWriteLock(ref,
      () => ref.read(managedUsersProvider.notifier).toggleUserStatus(user.id));
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

Future<void> _showCredentialEditor(
  BuildContext context,
  WidgetRef ref,
  UserEntity user, {
  required UserRole managerRole,
  required int passwordMinLength,
}) async {
  final managerLabel =
      managerRole == UserRole.superOwner ? 'Super Owner' : 'Owner';
  final formKey = GlobalKey<FormState>();
  final managerUsername = TextEditingController(
    text: ref.read(sessionProvider).valueOrNull?.username ?? '',
  );
  final managerPassword = TextEditingController();
  final name = TextEditingController(text: user.name);
  final username = TextEditingController(text: user.username);
  final newPassword = TextEditingController();

  final result = await showSafeModalBottomSheet<_CredentialUpdate>(
    context: context,
    isScrollControlled: true,
    controllers: [
      managerUsername,
      managerPassword,
      name,
      username,
      newPassword
    ],
    builder: (sheetContext) => SafeArea(
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
              Text('Kelola kredensial akun',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Password lama tidak dapat ditampilkan. Verifikasi akun $managerLabel untuk mengubah nama, username, atau menetapkan password baru.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama panggilan'),
                validator: (value) =>
                    Validators.required(value, field: 'Nama panggilan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: username,
                decoration: const InputDecoration(labelText: 'Username akun'),
                validator: (value) =>
                    Validators.required(value, field: 'Username akun'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password baru (opsional)',
                  helperText:
                      'Kosongkan bila hanya mengubah nama atau username.',
                ),
                validator: (value) => value != null &&
                        value.isNotEmpty &&
                        value.length < passwordMinLength
                    ? 'Password minimal $passwordMinLength karakter'
                    : null,
              ),
              const Divider(height: 36),
              TextFormField(
                controller: managerUsername,
                decoration:
                    InputDecoration(labelText: 'Username $managerLabel'),
                validator: (value) =>
                    Validators.required(value, field: 'Username $managerLabel'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: managerPassword,
                obscureText: true,
                decoration:
                    InputDecoration(labelText: 'Password $managerLabel'),
                validator: (value) =>
                    Validators.required(value, field: 'Password $managerLabel'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(
                    sheetContext,
                    _CredentialUpdate(
                      managerUsername: managerUsername.text.trim(),
                      managerPassword: managerPassword.text,
                      name: name.text.trim(),
                      username: username.text.trim(),
                      password: newPassword.text,
                    ),
                  );
                },
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Verifikasi dan simpan'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (result == null || !isCurrentPage(context)) return;

  final saved = await withNavigationWriteLock(
      ref,
      () => ref.read(managedUsersProvider.notifier).updateCredentials(
            user: user,
            managerUsername: result.managerUsername,
            managerPassword: result.managerPassword,
            name: result.name,
            username: result.username,
            password: result.password,
          ));
  if (!context.mounted) return;
  saved.when(
    success: (_) => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kredensial akun berhasil diperbarui.')),
    ),
    error: (failure) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failure.message)),
    ),
  );
}

class _UserFormResult {
  final UserEntity user;
  final String password;
  final bool openCredentials;

  const _UserFormResult({
    required this.user,
    required this.password,
    this.openCredentials = false,
  });
}

class _CredentialUpdate {
  final String managerUsername;
  final String managerPassword;
  final String name;
  final String username;
  final String password;

  const _CredentialUpdate({
    required this.managerUsername,
    required this.managerPassword,
    required this.name,
    required this.username,
    required this.password,
  });
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
