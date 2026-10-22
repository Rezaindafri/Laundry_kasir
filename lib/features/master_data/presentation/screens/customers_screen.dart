import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/navigation_write_guard.dart';
import '../../../../core/widgets/safe_modal_sheet.dart';
import '../../../../core/widgets/unsaved_changes_guard.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../../../shared/enums/user_role.dart';

import 'customer_search_delegate.dart';
import 'customer_detail_screen.dart';
import '../../domain/entities/customer_entity.dart';
import '../providers/master_data_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  final bool openCreateForm;

  const CustomersScreen({this.openCreateForm = false, super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  var _quickCreateHandled = false;
  var _formOpen = false;

  @override
  void initState() {
    super.initState();
    _scheduleQuickCreate();
  }

  @override
  void didUpdateWidget(covariant CustomersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.openCreateForm && widget.openCreateForm) {
      _scheduleQuickCreate();
    }
  }

  void _scheduleQuickCreate() {
    if (!widget.openCreateForm || _quickCreateHandled) return;
    _quickCreateHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!isCurrentPage(context)) return;
      await _showForm(context, ref);
      // The handled flag prevents reopening; do not clear the route's query
      // with go(), which would erase the page the quick action came from.
    });
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final user = ref.watch(sessionProvider).valueOrNull;
    final currentRole = user?.role;
    final isKasir = currentRole == UserRole.kasir;

    return NavigationWriteGuard(
        child: Scaffold(
      drawer: user == null ? null : AppNavigationDrawer(user: user),
      appBar: AppBar(
          automaticallyImplyLeading: true,
          title: const Text('Pelanggan'),
          actions: [
            IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Cari pelanggan',
                onPressed: () {
                  showSearch(
                      context: context, delegate: CustomerSearchDelegate());
                })
          ]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showForm(context, ref),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Tambah')),
      body: customers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
            message: 'Gagal memuat pelanggan',
            onRetry: () => ref.read(customersProvider.notifier).refresh()),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.read(customersProvider.notifier).refresh(),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  children: const [
                    SizedBox(height: 150),
                    Icon(Icons.people_outline,
                        size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text('Pelanggan belum tersedia',
                        textAlign: TextAlign.center),
                    SizedBox(height: 6),
                    Text(
                      'Tambahkan pelanggan pertama',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final customer = items[index];
                    return Card(
                        child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: .1),
                          foregroundColor: AppColors.primary,
                          child: Text(
                              customer.name.substring(0, 1).toUpperCase())),
                      title: Text(customer.name),
                      subtitle: Text(customer.phone?.isNotEmpty == true
                          ? customer.phone!
                          : 'Tanpa nomor HP'),
                      trailing: isKasir
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _showForm(context, ref, customer: customer),
                            ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CustomerDetailScreen(customer: customer),
                        ),
                      ),
                      onLongPress: isKasir
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Kasir tidak memiliki hak untuk menghapus pelanggan.',
                                  ),
                                ),
                              );
                            }
                          : () => _confirmDelete(context, ref, customer),
                    ));
                  },
                ),
        ),
      ),
    ));
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref,
      {CustomerEntity? customer}) async {
    if (_formOpen) return;
    _formOpen = true;
    final result = await showSafeModalBottomSheet<CustomerEntity>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => _CustomerFormSheet(customer: customer),
    );
    _formOpen = false;
    if (!isCurrentPage(context) || result == null) return;

    final saved = await withNavigationWriteLock(ref, () async {
      final saved = await ref.read(customersProvider.notifier).save(result);
      if (saved.isSuccess) {
        await ref.read(customersProvider.notifier).refresh();
      }
      return saved;
    });
    if (mounted)
      _showResult(context, saved, 'Data pelanggan berhasil disimpan.');
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, CustomerEntity customer) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Hapus pelanggan?'),
                content: Text('${customer.name} akan dihapus permanen.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Batal')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Hapus'))
                ]));
    if (confirmed == true && mounted) {
      final result = await withNavigationWriteLock(
          ref, () => ref.read(customersProvider.notifier).delete(customer.id));
      if (context.mounted) {
        _showResult(context, result, 'Data pelanggan berhasil dihapus.');
      }
    }
  }

  void _showResult(
          BuildContext context, dynamic result, String successMessage) =>
      result.when(
          success: (_) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(successMessage))),
          error: (Failure failure) => ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message))));
}

/// Owns its controllers for the entire lifetime of the bottom-sheet route.
/// They must not be owned by [_CustomersScreenState], because that state gets
/// the result before the bottom-sheet exit animation has fully unmounted its
/// TextFormFields.
class _CustomerFormSheet extends StatefulWidget {
  final CustomerEntity? customer;

  const _CustomerFormSheet({this.customer});

  @override
  State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  CustomerGender? _gender;

  bool get _hasChanges =>
      _name.text != (widget.customer?.name ?? '') ||
      _phone.text != (widget.customer?.phone ?? '') ||
      _address.text != (widget.customer?.address ?? '') ||
      _gender != widget.customer?.gender;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.customer?.name);
    _phone = TextEditingController(text: widget.customer?.phone);
    _address = TextEditingController(text: widget.customer?.address);
    _gender = widget.customer?.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(
      CustomerEntity(
        id: widget.customer?.id ?? '',
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        gender: _gender,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset =
        MediaQuery.viewInsetsOf(context).bottom.clamp(0.0, 360.0).toDouble();
    return UnsavedChangesGuard(
      hasUnsavedChanges: () => _hasChanges,
      listenables: [_name, _phone, _address],
      child: AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.customer == null ? 'Pelanggan Baru' : 'Ubah Pelanggan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Nama pelanggan'),
                  validator: (value) =>
                      Validators.required(value, field: 'Nama pelanggan'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Nomor HP (opsional)'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? null
                      : Validators.phone(value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration:
                      const InputDecoration(labelText: 'Alamat (opsional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<CustomerGender?>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Jenis kelamin (opsional)',
                  ),
                  items: [
                    const DropdownMenuItem<CustomerGender?>(
                      value: null,
                      child: Text('Tidak dipilih'),
                    ),
                    ...CustomerGender.values.map(
                      (item) => DropdownMenuItem<CustomerGender?>(
                        value: item,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _save, child: const Text('Simpan')),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi'))
          ])));
}
