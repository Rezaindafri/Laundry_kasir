import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/enums/user_role.dart';

import 'customer_search_delegate.dart';
import 'customer_detail_screen.dart';
import '../../domain/entities/customer_entity.dart';
import '../providers/master_data_providers.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final user = ref.watch(sessionProvider).valueOrNull;
    final currentRole = user?.role;
    final isKasir = currentRole == UserRole.kasir;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Pelanggan'), actions: [IconButton(icon: const Icon(Icons.search), tooltip: 'Cari pelanggan', onPressed: () { final list = customers.valueOrNull == null ? const <CustomerEntity>[] : customers.valueOrNull!; showSearch(context: context, delegate: CustomerSearchDelegate(list)); })]),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showForm(context, ref),
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Tambah')),
      body: customers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
            message: 'Data pelanggan gagal dimuat: $error',
            onRetry: () => ref.read(customersProvider.notifier).refresh()),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.read(customersProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final customer = items[index];
              return Card(
                  child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: .1),
                    foregroundColor: AppColors.primary,
                    child: Text(customer.name.substring(0, 1).toUpperCase())),
                title: Text(customer.name),
                subtitle: Text(customer.phone?.isNotEmpty == true
                    ? customer.phone!
                    : 'Tanpa nomor HP'),
                trailing: isKasir
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showForm(context, ref, customer: customer),
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(customer: customer),
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
    );
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref,
      {CustomerEntity? customer}) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: customer?.name);
    final phone = TextEditingController(text: customer?.phone);
    final address = TextEditingController(text: customer?.address);
    var gender = customer?.gender;
    final result = await showModalBottomSheet<CustomerEntity>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setState) => Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24,
                      24 + MediaQuery.viewInsetsOf(sheetContext).bottom),
                  child: Form(
                      key: formKey,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            customer == null
                                ? 'Pelanggan Baru'
                                : 'Ubah Pelanggan',
                            style: Theme.of(sheetContext).textTheme.titleLarge),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Nama pelanggan'),
                            validator: (value) => Validators.required(value,
                                field: 'Nama pelanggan')),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                                labelText: 'Nomor HP (opsional)'),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? null
                                    : Validators.phone(value)),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: address,
                            decoration: const InputDecoration(
                                labelText: 'Alamat (opsional)')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<CustomerGender?>(
                            initialValue: gender,
                            decoration: const InputDecoration(
                                labelText: 'Jenis kelamin (opsional)'),
                            items: [
                              const DropdownMenuItem<CustomerGender?>(
                                  value: null, child: Text('Tidak dipilih')),
                              ...CustomerGender.values.map((item) =>
                                  DropdownMenuItem<CustomerGender?>(
                                      value: item, child: Text(item.label)))
                            ],
                            onChanged: (value) =>
                                setState(() => gender = value)),
                        const SizedBox(height: 20),
                        FilledButton(
                            onPressed: () {
                              if (formKey.currentState!.validate())
                                Navigator.pop(
                                    sheetContext,
                                    CustomerEntity(
                                        id: customer?.id ?? '',
                                        name: name.text.trim(),
                                        phone: phone.text.trim().isEmpty
                                            ? null
                                            : phone.text.trim(),
                                        address: address.text.trim().isEmpty
                                            ? null
                                            : address.text.trim(),
                                        gender: gender));
                            },
                            child: const Text('Simpan')),
                      ])),
                )));
    if (result != null) {
      final saved = await ref.read(customersProvider.notifier).save(result);
      if (context.mounted) _showResult(context, saved);
    }
    name.dispose();
    phone.dispose();
    address.dispose();
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
    if (confirmed == true) {
      final result =
          await ref.read(customersProvider.notifier).delete(customer.id);
      if (context.mounted) _showResult(context, result);
    }
  }

  void _showResult(BuildContext context, dynamic result) => result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data pelanggan berhasil disimpan.'))),
      error: (Failure failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))));
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
