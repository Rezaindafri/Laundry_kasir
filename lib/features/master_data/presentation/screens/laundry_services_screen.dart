import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
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
          onPressed: () => _showServiceForm(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Tambah'),),
      body: services.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Data layanan gagal dimuat: $error')),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final service = items[index];
            return Card(
                child: ListTile(
              leading: Icon(Icons.local_laundry_service_outlined,
                  color: service.isActive
                      ? AppColors.primary
                      : AppColors.textSecondary,),
              title: Text(service.name),
              subtitle: Text(
                  '${_currency.format(service.price)} • ${service.pricingLabel} • ${service.estimatedHours} jam',),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showServiceForm(context, ref, service: service),
            ),);
          },
        ),
      ),
    );
  }

  Future<void> _showServiceForm(BuildContext context, WidgetRef ref,
      {LaundryServiceEntity? service,}) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: service?.name);
    final price = TextEditingController(text: service?.price.toString());
    final duration =
        TextEditingController(text: service?.estimatedHours.toString());
    var pricing = service?.pricingType ?? PricingType.perKg;
    var active = service?.isActive ?? true;
    final result = await showModalBottomSheet<LaundryServiceEntity>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) => Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 24, 24, 24 + MediaQuery.viewInsetsOf(ctx).bottom,),
                  child: Form(
                      key: formKey,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(service == null ? 'Layanan Baru' : 'Ubah Layanan',
                            style: Theme.of(ctx).textTheme.titleLarge,),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: name,
                            decoration: const InputDecoration(
                                labelText: 'Nama layanan',),
                            validator: (value) => Validators.required(value,
                                field: 'Nama layanan',),),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: price,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Harga'),
                            validator: (value) => Validators.positiveNumber(
                                value,
                                field: 'Harga',),),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: duration,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Estimasi selesai (jam)',),
                            validator: (value) => Validators.positiveNumber(
                                value,
                                field: 'Estimasi',),),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<PricingType>(
                            initialValue: pricing,
                            decoration: const InputDecoration(
                                labelText: 'Jenis perhitungan',),
                            items: const [
                              DropdownMenuItem(
                                  value: PricingType.perKg,
                                  child: Text('Per Kg'),),
                              DropdownMenuItem(
                                  value: PricingType.perItem,
                                  child: Text('Per Item'),),
                            ],
                            onChanged: (value) =>
                                setState(() => pricing = value!),),
                        SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Layanan aktif'),
                            value: active,
                            onChanged: (value) =>
                                setState(() => active = value),),
                        FilledButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                Navigator.pop(
                                    ctx,
                                    LaundryServiceEntity(
                                        id: service?.id ?? '',
                                        name: name.text.trim(),
                                        price: int.parse(price.text),
                                        estimatedHours:
                                            int.parse(duration.text),
                                        pricingType: pricing,
                                        isActive: active,),);
                              }
                            },
                            child: const Text('Simpan'),),
                      ],),),
                ),),);
    if (result != null) {
      await ref.read(laundryServicesProvider.notifier).save(result);
    }
    name.dispose();
    price.dispose();
    duration.dispose();
  }
}
