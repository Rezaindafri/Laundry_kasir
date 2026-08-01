import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/whatsapp_launcher.dart';
import '../../domain/entities/customer_entity.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final CustomerEntity customer;
  const CustomerDetailScreen({required this.customer, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Detail Pelanggan')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: CircleAvatar(radius: 34, backgroundColor: AppColors.primary.withValues(alpha: .1), foregroundColor: AppColors.primary, child: Text(customer.name.substring(0, 1).toUpperCase(), style: Theme.of(context).textTheme.headlineMedium))),
        const SizedBox(height: 16), Center(child: Text(customer.name, style: Theme.of(context).textTheme.titleLarge)), const Divider(height: 32),
        _Row('Nomor HP', customer.phone?.isNotEmpty == true ? customer.phone! : '-'), _Row('Alamat', customer.address?.isNotEmpty == true ? customer.address! : '-'), _Row('Jenis kelamin', customer.gender?.label ?? '-'),
      ]))), const SizedBox(height: 16),
      FilledButton.icon(onPressed: customer.phone?.isNotEmpty == true ? () async { final opened = await WhatsAppLauncher.open(customer.phone, message: 'Halo ${customer.name},'); if (context.mounted && !opened) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor WhatsApp tidak valid atau aplikasi tidak tersedia.'))); } : null, icon: const Icon(Icons.chat_outlined), label: const Text('Hubungi via WhatsApp')),
    ]),
  );
}
class _Row extends StatelessWidget { final String label; final String value; const _Row(this.label, this.value); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.bodySmall)), Expanded(child: Text(value))])); }