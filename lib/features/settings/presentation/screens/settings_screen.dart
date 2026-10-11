import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/widgets/navigation_write_guard.dart';
import '../../../../core/widgets/safe_modal_sheet.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../printing/domain/entities/printer_device.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../domain/entities/laundry_settings.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    if (user?.role.apiValue == 'super_owner') {
      return NavigationWriteGuard(
          child: Scaffold(
        drawer: AppNavigationDrawer(user: user!),
        appBar: AppBar(
          title: const Text('Pengaturan'),
          automaticallyImplyLeading: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Keluar',
              onPressed: () => _confirmLogout(context, ref),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            _ProfileSection(),
            SizedBox(height: 24),
            _SuperOwnerSettingsSection(),
          ],
        ),
      ));
    }

    final settings = ref.watch(laundrySettingsProvider);
    return NavigationWriteGuard(
        child: Scaffold(
      drawer: user == null ? null : AppNavigationDrawer(user: user),
      appBar: AppBar(
        title: const Text('Pengaturan'),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Keluar',
            onPressed: () => _confirmLogout(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Pengaturan gagal dimuat: $error')),
        data: (value) => _SettingsForm(value: value),
      ),
    ));
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar Aplikasi'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(sessionProvider.notifier).logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  final LaundrySettings value;
  const _SettingsForm({required this.value});

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late String _paper;
  String? _printerMac;
  String? _printerName;
  bool _loadingPrinters = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.value.businessName);
    _phone = TextEditingController(text: widget.value.phone);
    _address = TextEditingController(text: widget.value.address);
    _paper = widget.value.paperSize;
    _printerMac = widget.value.defaultPrinter;
    _printerName = widget.value.defaultPrinterName;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _choosePrinter() async {
    setState(() => _loadingPrinters = true);
    try {
      final devices =
          await ref.read(printerDeviceServiceProvider).getPairedDevices();
      if (!mounted) return;
      if (devices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Tidak ada printer Bluetooth yang telah dipasangkan di perangkat ini.')));
        return;
      }
      final selected = await showModalBottomSheet<PrinterDevice>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Pilih printer Bluetooth')),
              ...devices.map((device) => ListTile(
                    leading: const Icon(Icons.print_outlined),
                    title: Text(device.name.isEmpty
                        ? 'Printer tanpa nama'
                        : device.name),
                    subtitle: Text(device.macAddress),
                    trailing: device.macAddress == _printerMac
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, device),
                  )),
            ],
          ),
        ),
      );
      if (selected != null) {
        setState(() {
          _printerMac = selected.macAddress;
          _printerName = selected.name;
        });
      }
    } on PrinterException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final value = widget.value.copyWith(
      businessName: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      paperSize: _paper,
      defaultPrinter: _printerMac,
      defaultPrinterName: _printerName,
    );
    final canManageBusiness =
        ref.read(sessionProvider).valueOrNull?.role.canManageServicePrice ??
            false;
    try {
      if (canManageBusiness) {
        await withNavigationWriteLock(
            ref, () => ref.read(laundrySettingsProvider.notifier).save(value));
      } else {
        await withNavigationWriteLock(
            ref,
            () => ref
                .read(laundrySettingsProvider.notifier)
                .saveDeviceSettings(value));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengaturan tersimpan.')),
        );
      }
    } on ServerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionProvider).valueOrNull?.role;
    final canManageBusiness = role?.canManageServicePrice ?? false;
    final canBackupRestore = role?.canBackupRestore ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _ProfileSection(),
        const SizedBox(height: 24),
        Text('Informasi Usaha', style: Theme.of(context).textTheme.titleMedium),
        if (!canManageBusiness) ...[
          const SizedBox(height: 4),
          Text(
            'Informasi usaha dikelola oleh owner.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                  controller: _name,
                  enabled: canManageBusiness,
                  decoration: const InputDecoration(labelText: 'Nama usaha'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nama pengguna wajib diisi'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  enabled: canManageBusiness,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Nomor telepon')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _address,
                  enabled: canManageBusiness,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Alamat')),
              const SizedBox(height: 24),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Printer',
                      style: Theme.of(context).textTheme.titleMedium)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bluetooth_connected),
                  title: Text(_printerMac == null || _printerMac!.isEmpty
                      ? 'Belum ada printer aplikasi'
                      : (_printerName?.isNotEmpty ?? false)
                          ? _printerName!
                          : 'Printer Bluetooth'),
                  subtitle: Text(_printerMac == null || _printerMac!.isEmpty
                      ? 'Pilih printer untuk digunakan aplikasi ini'
                      : 'Dipilih untuk aplikasi ini • $_printerMac'),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _loadingPrinters ? null : _choosePrinter,
                  icon: _loadingPrinters
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(_printerMac == null || _printerMac!.isEmpty
                      ? 'Pilih printer'
                      : 'Ganti printer'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _paper,
                decoration: const InputDecoration(labelText: 'Ukuran kertas'),
                items: const [
                  DropdownMenuItem(value: '58 mm', child: Text('58 mm')),
                  DropdownMenuItem(value: '80 mm', child: Text('80 mm')),
                ],
                onChanged: (value) => setState(() => _paper = value!),
              ),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _save,
                  child: Text(canManageBusiness
                      ? 'Simpan pengaturan usaha'
                      : 'Simpan pengaturan perangkat')),
            ],
          ),
        ),
        if (canBackupRestore) ...[
          const SizedBox(height: 28),
          const _BackupRestoreSection(),
        ],
      ],
    );
  }
}

class _ProfileSection extends ConsumerWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final role = ref.watch(sessionProvider).valueOrNull?.role;
    final canChangeCredentials = role?.apiValue != 'kasir';
    final passwordMinLength = canChangeCredentials
        ? ref.watch(accountPasswordMinLengthProvider).valueOrNull ?? 6
        : 6;
    return profile.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Profil akun tidak dapat dimuat.'),
      data: (user) => Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(user.name),
              subtitle: Text('@${user.username}'),
            ),
            const Divider(height: 1),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _editProfile(
                    context,
                    ref,
                    user,
                    canChangeUsername: canChangeCredentials,
                  ),
                  child: Text(
                    canChangeCredentials ? 'Ubah profil' : 'Ubah nama',
                  ),
                ),
                if (canChangeCredentials)
                  TextButton(
                    onPressed: () => _changePassword(
                      context,
                      ref,
                      passwordMinLength: passwordMinLength,
                    ),
                    child: const Text('Ganti password'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, WidgetRef ref, UserModel user,
      {required bool canChangeUsername}) async {
    final name = TextEditingController(text: user.name);
    final username = TextEditingController(text: user.username);
    final formKey = GlobalKey<FormState>();
    final result = await showSafeModalBottomSheet<_ProfileInput>(
      context: context,
      isScrollControlled: true,
      controllers: [name, username],
      builder: (sheetContext) => SingleChildScrollView(
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
              Text('Ubah Profil',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Nama wajib diisi'
                    : null,
              ),
              if (canChangeUsername) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Username wajib diisi'
                      : null,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(
                    sheetContext,
                    _ProfileInput(
                      name.text.trim(),
                      canChangeUsername ? username.text.trim() : null,
                    ),
                  );
                },
                child: const Text('Simpan profil'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !isCurrentPage(context)) return;

    try {
      await withNavigationWriteLock(ref, () async {
        final updated = await ref
            .read(profileRemoteDataSourceProvider)
            .updateProfile(name: result.name, username: result.username);
        await ref.read(authLocalDataSourceProvider).updateSavedUser(updated);
        await ref
            .read(sessionProvider.notifier)
            .replaceCurrentUser(updated.toEntity());
        ref.invalidate(currentProfileProvider);
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui.')),
        );
      }
    } on ServerException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _changePassword(
    BuildContext context,
    WidgetRef ref, {
    required int passwordMinLength,
  }) async {
    final currentPassword = TextEditingController();
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showSafeModalBottomSheet<_PasswordInput>(
      context: context,
      isScrollControlled: true,
      controllers: [currentPassword, password, confirmation],
      builder: (sheetContext) => SingleChildScrollView(
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
              Text('Ganti Password',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                controller: currentPassword,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Password saat ini'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Password saat ini wajib diisi'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password baru'),
                validator: (value) =>
                    value == null || value.length < passwordMinLength
                        ? 'Password minimal $passwordMinLength karakter'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Konfirmasi password baru'),
                validator: (value) => value != password.text
                    ? 'Konfirmasi password tidak sama'
                    : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(
                    sheetContext,
                    _PasswordInput(currentPassword.text, password.text),
                  );
                },
                child: const Text('Ganti password'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !isCurrentPage(context)) return;

    try {
      await withNavigationWriteLock(
          ref,
          () => ref.read(profileRemoteDataSourceProvider).updatePassword(
                currentPassword: result.currentPassword,
                password: result.password,
              ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diperbarui.')),
        );
      }
    } on ServerException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _BackupRestoreSection extends ConsumerStatefulWidget {
  const _BackupRestoreSection();

  @override
  ConsumerState<_BackupRestoreSection> createState() =>
      _BackupRestoreSectionState();
}

class _BackupRestoreSectionState extends ConsumerState<_BackupRestoreSection> {
  bool _busy = false;

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final bytes =
          await ref.read(laundrySettingsProvider.notifier).downloadBackup();
      final name =
          'backup-konfigurasi-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'application/json', name: name)],
        subject: 'Backup konfigurasi usaha laundry',
        fileNameOverrides: [name],
      );
    } on ServerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = selected?.files.single.bytes;
    if (bytes == null || !mounted) return;
    try {
      final backup =
          Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Pulihkan konfigurasi?'),
          content: const Text(
            'Nama usaha, telepon, dan alamat saat ini akan diganti. Data pelanggan dan transaksi tidak diubah.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Pulihkan'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _busy = true);
      await withNavigationWriteLock(
          ref,
          () =>
              ref.read(laundrySettingsProvider.notifier).restoreBackup(backup));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konfigurasi berhasil dipulihkan.')),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Berkas backup bukan JSON yang valid.')),
        );
      }
    } on ServerException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backup konfigurasi',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Hanya identitas usaha yang dibackup; pelanggan dan transaksi tidak termasuk.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _backup,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Buat backup'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _restore,
                icon: const Icon(Icons.settings_backup_restore_outlined),
                label: const Text('Pulihkan backup'),
              ),
            ],
          ),
        ],
      );
}

class _ProfileInput {
  final String name;
  final String? username;
  const _ProfileInput(this.name, this.username);
}

class _SuperOwnerSettingsSection extends ConsumerWidget {
  const _SuperOwnerSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(superOwnerSettingsProvider);
    return settings.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined),
          title: const Text('Pengaturan sistem tidak dapat dimuat'),
          subtitle: Text('$error'),
          trailing: IconButton(
            onPressed: () => ref.invalidate(superOwnerSettingsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ),
      ),
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tata kelola akun',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Super Owner mengelola struktur akun, bukan usaha, printer, atau aktivitas operasional.',
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Kebijakan password'),
              subtitle: Text(
                'Password akun baru dan perubahan password minimal ${value.passwordMinLength} karakter.',
              ),
              trailing: TextButton(
                onPressed: () =>
                    _editPasswordPolicy(context, ref, value.passwordMinLength),
                child: const Text('Ubah'),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(
                value.apiStatus == 'online'
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
              ),
              title: Text(value.applicationName),
              subtitle: Text(
                'API ${value.apiStatus == 'online' ? 'terhubung' : value.apiStatus}'
                '${value.serverTime == null ? '' : ' • Server: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value.serverTime!.toLocal())}'}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Riwayat perubahan akun',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Hanya mencatat perubahan Owner dan Kasir; transaksi serta laporan tidak ditampilkan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: value.accountChanges.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Belum ada perubahan akun yang tercatat.'),
                  )
                : Column(
                    children: value.accountChanges
                        .map(
                          (change) => ListTile(
                            leading: const Icon(Icons.manage_accounts_outlined),
                            title:
                                Text('${change.label}: ${change.subjectName}'),
                            subtitle: Text(
                              '${change.actorName}${change.actorUsername == null ? '' : ' (@${change.actorUsername})'}'
                              '${change.createdAt == null ? '' : ' • ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(change.createdAt!.toLocal())}'}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPasswordPolicy(
    BuildContext context,
    WidgetRef ref,
    int currentValue,
  ) async {
    final controller = TextEditingController(text: currentValue.toString());
    final formKey = GlobalKey<FormState>();
    final result = await showSafeModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      controllers: [controller],
      builder: (sheetContext) => SingleChildScrollView(
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
              Text('Kebijakan password',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'Berlaku untuk password baru dan perubahan password berikutnya. Password lama tidak diubah.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Panjang minimum password',
                  suffixText: 'karakter',
                ),
                validator: (raw) {
                  final value = int.tryParse(raw ?? '');
                  if (value == null || value < 6 || value > 128) {
                    return 'Masukkan angka 6 sampai 128';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  Navigator.pop(sheetContext, int.parse(controller.text));
                },
                child: const Text('Simpan kebijakan'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !isCurrentPage(context)) return;
    try {
      await withNavigationWriteLock(
          ref,
          () => ref
              .read(profileRemoteDataSourceProvider)
              .updatePasswordMinLength(result));
      ref.invalidate(superOwnerSettingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kebijakan password diperbarui.')),
        );
      }
    } on ServerException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _PasswordInput {
  final String currentPassword;
  final String password;
  const _PasswordInput(this.currentPassword, this.password);
}
