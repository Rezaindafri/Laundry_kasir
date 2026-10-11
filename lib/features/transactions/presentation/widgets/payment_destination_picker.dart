import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/domain/entities/payment_destination.dart';
import '../../../settings/presentation/providers/payment_destination_providers.dart';
import '../../domain/entities/transaction_entity.dart';

class PaymentDestinationPicker extends ConsumerWidget {
  const PaymentDestinationPicker(
      {required this.method,
      required this.onChanged,
      this.value,
      this.requiredForPayment = true,
      super.key});
  final PaymentMethod method;
  final int? value;
  final ValueChanged<int?> onChanged;
  final bool requiredForPayment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (method == PaymentMethod.cash) return const SizedBox.shrink();
    final destinations = ref.watch(paymentDestinationsProvider);
    return destinations.when(
        loading: () => FormField<int>(
            validator: (_) => requiredForPayment
                ? 'Tunggu tujuan pembayaran selesai dimuat.'
                : null,
            builder: (_) => const LinearProgressIndicator()),
        error: (_, __) => FormField<int>(
            validator: (_) => requiredForPayment
                ? 'Muat ulang tujuan pembayaran sebelum mencatat pembayaran.'
                : null,
            builder: (_) => Column(children: [
                  const Text('Tujuan pembayaran belum dapat dimuat.'),
                  TextButton(
                      onPressed: () =>
                          ref.invalidate(paymentDestinationsProvider),
                      child: const Text('Coba lagi')),
                ])),
        data: (all) {
          final items = all
              .where((item) => item.isActive && item.kind == method.name)
              .toList();
          if (items.isEmpty && value == null)
            return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                    'Owner belum menambahkan tujuan pembayaran untuk metode ini.'));
          // Never silently replace a failed payment's previous destination. That
          // would change its retry payload/UUID and risk an unintended new payment.
          if (value != null && !items.any((item) => item.id == value)) {
            return Column(children: [
              const Text(
                  'Tujuan sebelumnya tidak tersedia. Periksa riwayat pembayaran sebelum memilih tujuan lain.'),
              DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Pilih tujuan yang tersedia'),
                  validator: (_) => requiredForPayment
                      ? 'Tujuan sebelumnya tidak tersedia.'
                      : null,
                  items: items
                      .map((item) => DropdownMenuItem(
                          value: item.id, child: Text(item.label)))
                      .toList(),
                  onChanged: onChanged),
            ]);
          }
          final selectedId = value ?? items.first.id;
          final selected = items.firstWhere((item) => item.id == selectedId);
          if (selectedId != value) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) onChanged(selectedId);
            });
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                    key: ValueKey('${method.name}:$selectedId'),
                    initialValue: selectedId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Tujuan pembayaran'),
                    items: items
                        .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.label,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    validator: (_) => requiredForPayment && value == null
                        ? 'Pilih tujuan pembayaran.'
                        : null,
                    onChanged: onChanged),
                const SizedBox(height: 12),
                PaymentDestinationInfo(destination: selected),
              ]);
        });
  }
}

class PaymentDestinationInfo extends ConsumerWidget {
  const PaymentDestinationInfo({required this.destination, super.key});
  final PaymentDestination destination;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: destination.kind == 'transfer'
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(destination.bankName ?? '',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  SelectableText(destination.accountNumber ?? '',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('Atas nama ${destination.accountHolder ?? ""}'),
                  TextButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Salin nomor rekening'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                            text: destination.accountNumber ?? ''));
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Nomor rekening disalin.')));
                      }),
                ])
              : Column(children: [
                  Text(destination.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ref
                      .watch(paymentDestinationImageProvider(destination.id))
                      .when(
                          loading: () => const SizedBox(
                              height: 200,
                              child:
                                  Center(child: CircularProgressIndicator())),
                          error: (_, __) => Column(children: [
                                const Text('Gambar QRIS belum dapat dimuat.'),
                                TextButton(
                                    onPressed: () => ref.invalidate(
                                        paymentDestinationImageProvider(
                                            destination.id)),
                                    child: const Text('Muat ulang QRIS'))
                              ]),
                          data: (bytes) => Image.memory(bytes,
                              height: 220,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Text(
                                  'Berkas QRIS tidak dapat ditampilkan.'))),
                ])));
}
