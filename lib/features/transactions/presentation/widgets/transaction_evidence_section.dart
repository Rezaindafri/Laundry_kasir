import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/business_time.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';
import 'transaction_proof_dialog.dart';

class TransactionEvidenceSection extends ConsumerWidget {
  const TransactionEvidenceSection({required this.transaction, super.key});
  final TransactionEntity transaction;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines =
        transaction.details.where((line) => line.hasProofImage).toList();
    final hasPhoto = lines.isNotEmpty || transaction.hasProofImage;
    final firstId = lines.firstOrNull?.id;
    final bytes = hasPhoto
        ? (firstId == null
            ? ref.watch(transactionProofProvider(transaction.id))
            : ref
                .watch(transactionLineProofProvider((transaction.id, firstId))))
        : null;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Bukti pengambilan',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (!hasPhoto)
                    const Text(
                        'Foto opsional, belum tersedia'),
                  if (hasPhoto) ...[
                    const Text(
                        'Bukti pengambilan, bukan pembayaran'),
                    const SizedBox(height: 12),
                    bytes!.when(
                        loading: () => const SizedBox(
                            height: 120,
                            child: Center(child: CircularProgressIndicator())),
                        error: (_, __) => const Text(
                            'Pratinjau gagal dimuat'),
                        data: (value) => Image.memory(value,
                            height: 160,
                            cacheWidth: 480,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('Foto tidak dapat ditampilkan.'))),
                    if (lines.isEmpty)
                      TextButton.icon(
                          icon: const Icon(Icons.zoom_in),
                          label: const Text('Lihat foto bukti'),
                          onPressed: () => _open(context)),
                    ...lines.map((line) => TextButton.icon(
                        icon: const Icon(Icons.photo_outlined),
                        label: Text(
                            'Bukti ${line.name}${line.collectedAt == null ? "" : " · ${DateFormat('dd MMM, HH:mm', 'id_ID').format(BusinessTime.wallTime(line.collectedAt!))} WIB"}'),
                        onPressed: () => _open(context, detailId: line.id))),
                  ],
                ])));
  }

  void _open(BuildContext context, {String? detailId}) => showDialog<void>(
      context: context,
      builder: (_) => TransactionProofDialog(
          transactionId: transaction.id, detailId: detailId));
}

class TransactionPaymentHistory extends StatelessWidget {
  const TransactionPaymentHistory({required this.transaction, super.key});
  final TransactionEntity transaction;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Pembayaran tercatat',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (transaction.payments.isEmpty)
              const Text('Rincian pembayaran belum tersedia'),
            ...transaction.payments.map((payment) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: 'Rp',
                                  decimalDigits: 0)
                              .format(payment.amount),
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(payment.paidAt == null
                          ? 'Waktu tidak tersedia'
                          : '${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(BusinessTime.wallTime(payment.paidAt!))} WIB'),
                      Text(switch (payment.method) {
                        'cash' => 'Tunai',
                        'qris' => 'QRIS',
                        'transfer' => 'Transfer bank',
                        _ => 'Metode tidak tersedia'
                      }),
                      if (payment.method != 'cash')
                        Text(payment.destinationLabel ??
                            'Tujuan pembayaran tidak tercatat'),
                      Text(
                          'Dicatat oleh ${payment.recorderName ?? "Informasi tidak tersedia"}'),
                      if (payment.note?.isNotEmpty == true) Text(payment.note!),
                    ]))),
          ])));
}
