import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/laundry_service_entity.dart';
import '../providers/master_data_providers.dart';

class LaundryServicesScreen extends ConsumerWidget {
  const LaundryServicesScreen({super.key});
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(laundryServicesProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Layanan Laundry')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showForm(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Tambah')),
        body: services.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Data layanan gagal dimuat: $error')),
            data: (items) => RefreshIndicator(
                onRefresh: () =>
                    ref.read(laundryServicesProvider.notifier).refresh(),
                child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final service = items[index];
                      return Card(
                          child: ListTile(
                              leading: Icon(
                                  Icons.local_laundry_service_outlined,
                                  color: service.isActive
                                      ? AppColors.primary
                                      : AppColors.textSecondary),
                              title: Text(service.name),
                              subtitle: Text(
                                  '${_currency.format(service.price)} • ${service.unit} • ${service.estimatedDurationLabel}'),
                              trailing: const Icon(Icons.edit_outlined),
                              onTap: () =>
                                  _showForm(context, ref, service: service),
                              onLongPress: () =>
                                  _confirmDelete(context, ref, service)));
                    }))));
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref,
      {LaundryServiceEntity? service}) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: service?.name);
    final price = TextEditingController(text: service?.price.toString());
    final unit = TextEditingController(text: service?.unit);
    final duration =
        TextEditingController(text: service?.estimatedHours.toString());
    var estimateUnit = service?.estimateUnit ?? EstimateDurationUnit.hours;

    try {
      final result = await showModalBottomSheet<LaundryServiceEntity>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service == null ? 'Layanan Baru' : 'Ubah Layanan',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Nama layanan'),
                      validator: (value) =>
                          Validators.required(value, field: 'Nama layanan'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Harga'),
                      validator: (value) =>
                          Validators.positiveNumber(value, field: 'Harga'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: unit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        hintText: 'Contoh: kg, item, load, helai',
                      ),
                      validator: (value) =>
                          Validators.required(value, field: 'Unit'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimasi selesai',
                      ),
                      validator: (value) =>
                          Validators.positiveNumber(value, field: 'Estimasi'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<EstimateDurationUnit>(
                      initialValue: estimateUnit,
                      decoration: const InputDecoration(
                        labelText: 'Satuan estimasi',
                      ),
                      items: EstimateDurationUnit.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == EstimateDurationUnit.hours
                                    ? 'Jam'
                                    : 'Hari',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          estimateUnit = value ?? EstimateDurationUnit.hours,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () {
                        if (formKey.currentState == null) {
                          return;
                        }

                        final isValid = formKey.currentState!.validate();
                        if (isValid == false) {
                          return;
                        }

                        if (Navigator.canPop(ctx)) {
                          Navigator.of(ctx).pop(
                            LaundryServiceEntity(
                              id: service?.id ?? '',
                              name: name.text.trim(),
                              price: double.parse(
                                price.text.replaceAll(',', '.'),
                              ),
                              unit: unit.text.trim(),
                              estimatedHours: int.parse(duration.text),
                              estimateUnit: estimateUnit,
                              isActive: service?.isActive ?? true,
                            ),
                          );
                        }
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

      if (!context.mounted) return;
      if (result != null) {
        final saved = await ref.read(laundryServicesProvider.notifier).save(result);
        if (context.mounted) _showResult(context, saved);
      }
    } finally {
      name.dispose();
      price.dispose();
      unit.dispose();
      duration.dispose();
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, LaundryServiceEntity service) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
                title: const Text('Hapus layanan?'),
                content: Text('${service.name} akan dihapus permanen.'),
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
          await ref.read(laundryServicesProvider.notifier).delete(service.id);
      if (context.mounted) _showResult(context, result);
    }
  }

  void _showResult(BuildContext context, dynamic result) => result.when(
      success: (_) => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data layanan berhasil disimpan.'))),
      error: (Failure failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))));
}
