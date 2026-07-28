import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/customer_entity.dart';
import '../providers/master_data_providers.dart';

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerForm(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Tambah'),
      ),
      body: customers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _ErrorState(message: 'Data pelanggan gagal dimuat: $error'),
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
                    child: Text(customer.name.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(customer.name),
                  subtitle: Text(customer.phone),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      _showCustomerForm(context, ref, customer: customer),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomerForm(BuildContext context, WidgetRef ref,
      {CustomerEntity? customer,}) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: customer?.name);
    final phone = TextEditingController(text: customer?.phone);
    final address = TextEditingController(text: customer?.address);
    final notes = TextEditingController(text: customer?.notes);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, 24 + MediaQuery.viewInsetsOf(sheetContext).bottom,),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(customer == null ? 'Pelanggan Baru' : 'Ubah Pelanggan',
                style: Theme.of(sheetContext).textTheme.titleLarge,),
            const SizedBox(height: 20),
            TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nama pelanggan'),
                validator: (value) =>
                    Validators.required(value, field: 'Nama pelanggan'),),
            const SizedBox(height: 12),
            TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor HP'),
                validator: Validators.phone,),
            const SizedBox(height: 12),
            TextFormField(
                controller: address,
                decoration:
                    const InputDecoration(labelText: 'Alamat (opsional)'),),
            const SizedBox(height: 12),
            TextFormField(
                controller: notes,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)'),),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(sheetContext, true);
                  }
                },
                child: const Text('Simpan'),),
          ],),
        ),
      ),
    );
    if (saved == true) {
      await ref.read(customersProvider.notifier).save(CustomerEntity(
          id: customer?.id ?? '',
          name: name.text.trim(),
          phone: phone.text.trim(),
          address: address.text.trim().isEmpty ? null : address.text.trim(),
          notes: notes.text.trim().isEmpty ? null : notes.text.trim(),),);
    }
    name.dispose();
    phone.dispose();
    address.dispose();
    notes.dispose();
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),),);
}
