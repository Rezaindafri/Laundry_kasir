import 'package:flutter/material.dart';
import '../../../../core/widgets/navigation_write_guard.dart';
import '../../../../core/widgets/safe_modal_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/laundry_service_entity.dart';
import '../providers/master_data_providers.dart';

class LaundryServicesScreen extends ConsumerWidget {
  const LaundryServicesScreen({super.key});
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(laundryServicesProvider);
    final currentRole = ref.watch(sessionProvider).valueOrNull?.role;
    final canManageServices = currentRole?.canManageServicePrice ?? false;
    return NavigationWriteGuard(
        child: Scaffold(
            appBar: AppBar(title: const Text('Layanan Laundry')),
            floatingActionButton: FloatingActionButton.extended(
                onPressed:
                    canManageServices ? () => _showForm(context, ref) : null,
                icon: const Icon(Icons.add),
                label: const Text('Tambah')),
            body: services.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Gagal memuat layanan'),
                        OutlinedButton(
                            onPressed: () => ref
                                .read(laundryServicesProvider.notifier)
                                .refresh(),
                            child: const Text('Coba lagi')),
                      ],
                    )),
                data: (items) => RefreshIndicator(
                    onRefresh: () =>
                        ref.read(laundryServicesProvider.notifier).refresh(),
                    child: items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: const [
                              SizedBox(height: 150),
                              Icon(Icons.local_laundry_service_outlined,
                                  size: 48, color: AppColors.textSecondary),
                              SizedBox(height: 12),
                              Text('Layanan belum tersedia',
                                  textAlign: TextAlign.center),
                              SizedBox(height: 6),
                              Text(
                                'Tambahkan layanan pertama',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
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
                                      trailing: canManageServices
                                          ? const Icon(Icons.edit_outlined)
                                          : null,
                                      onTap: canManageServices
                                          ? () => _showForm(context, ref,
                                              service: service)
                                          : () => _showNoAccessMessage(context),
                                      onLongPress: canManageServices
                                          ? () => _confirmDelete(
                                              context, ref, service)
                                          : () =>
                                              _showNoAccessMessage(context)));
                            })))));
  }

  void _showNoAccessMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kasir hanya dapat melihat katalog layanan.'),
      ),
    );
  }

  Future<void> _showForm(BuildContext context, WidgetRef ref,
      {LaundryServiceEntity? service}) async {
    if (!isCurrentPage(context)) return;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: service?.name);
    final price = TextEditingController(text: service?.price.toString());
    final unit = TextEditingController(text: service?.unit);
    final duration =
        TextEditingController(text: service?.estimatedHours.toString());
    var estimateUnit = service?.estimateUnit ?? EstimateDurationUnit.hours;
    var saving = false;
    String? saveError;

    try {
      final result = await showSafeModalBottomSheet<LaundryServiceEntity>(
        context: context,
        isScrollControlled: true,
        // Opening a new service is itself a creation flow: confirm dismissal
        // even before typing, unlike an unchanged existing service.
        hasUnsavedChanges: () =>
            service == null ||
            name.text != service.name ||
            price.text != service.price.toString() ||
            unit.text != service.unit ||
            duration.text != service.estimatedHours.toString() ||
            estimateUnit != service.estimateUnit,
        discardListenables: [name, price, unit, duration],
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, updateSheet) => AbsorbPointer(
                absorbing: saving,
                child: Padding(
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
                              decoration: const InputDecoration(
                                  labelText: 'Nama layanan'),
                              validator: (value) => Validators.required(value,
                                  field: 'Nama layanan'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: price,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration:
                                  const InputDecoration(labelText: 'Harga'),
                              validator: (value) => Validators.positiveNumber(
                                  value,
                                  field: 'Harga'),
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
                                helperText: '0/kosong: langsung siap',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty)
                                  return null;
                                final duration = int.tryParse(value.trim());
                                return duration == null ||
                                        duration < 0 ||
                                        duration > 3650
                                    ? 'Isi bilangan bulat 0–3650, atau kosongkan.'
                                    : null;
                              },
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
                              onChanged: (value) => estimateUnit =
                                  value ?? EstimateDurationUnit.hours,
                            ),
                            const SizedBox(height: 20),
                            if (saveError != null)
                              Text(saveError!,
                                  style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.error,
                                  )),
                            TextButton(
                              onPressed: () => Navigator.maybePop(ctx),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              onPressed: () async {
                                if (saving || !isCurrentPage(ctx)) return;
                                if (formKey.currentState == null) {
                                  return;
                                }

                                final isValid =
                                    formKey.currentState!.validate();
                                if (isValid == false) {
                                  return;
                                }

                                updateSheet(() {
                                  saving = true;
                                  saveError = null;
                                });
                                try {
                                  final saved = await withNavigationWriteLock(
                                    ref,
                                    () => ref
                                        .read(laundryServicesProvider.notifier)
                                        .save(
                                          LaundryServiceEntity(
                                            id: service?.id ?? '',
                                            name: name.text.trim(),
                                            price: double.parse(
                                              price.text.replaceAll(',', '.'),
                                            ),
                                            unit: unit.text.trim(),
                                            estimatedHours: int.tryParse(
                                                    duration.text.trim()) ??
                                                0,
                                            estimateUnit: estimateUnit,
                                            isActive: service?.isActive ?? true,
                                          ),
                                        ),
                                  );
                                  if (!ctx.mounted) return;
                                  saved.when(
                                    success: (item) =>
                                        Navigator.of(ctx).pop(item),
                                    error: (failure) => updateSheet(
                                        () => saveError = failure.message),
                                  );
                                } catch (_) {
                                  if (ctx.mounted) {
                                    updateSheet(() => saveError =
                                        'Gagal menyimpan layanan. Periksa data terbaru.');
                                  }
                                } finally {
                                  if (ctx.mounted)
                                    updateSheet(() => saving = false);
                                }
                              },
                              child: Text(saving ? 'Menyimpan…' : 'Simpan'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ))),
      );

      if (!isCurrentPage(context)) return;
      if (result != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Data layanan berhasil disimpan.'),
          ));
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
    if (confirmed == true && context.mounted) {
      final result = await withNavigationWriteLock(ref,
          () => ref.read(laundryServicesProvider.notifier).delete(service.id));
      if (context.mounted) {
        _showResult(context, result, 'Data layanan berhasil dihapus.');
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
