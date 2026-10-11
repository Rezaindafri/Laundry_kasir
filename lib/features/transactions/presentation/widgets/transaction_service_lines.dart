import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/business_time.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';

class TransactionServiceLines extends StatelessWidget {
  const TransactionServiceLines(
      {required this.transaction,
      this.selectedIds,
      this.onToggle,
      this.enabled = true,
      super.key});
  final TransactionEntity transaction;
  final Set<String>? selectedIds;
  final void Function(String id, bool selected)? onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
      children: transaction.serviceLines
          .map((line) => Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (onToggle != null)
                            Checkbox(
                                value: selectedIds?.contains(line.id) ?? false,
                                onChanged: enabled && line.isReady
                                    ? (value) =>
                                        onToggle!(line.id, value ?? false)
                                    : null),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(line.name,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                Text(
                                    '${line.quantity} ${line.unit} · ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(line.subtotal)}'),
                                const SizedBox(height: 4),
                                Text(
                                    line.estimatedFinishAt == null
                                        ? (line.hasKnownTiming
                                            ? 'Tanpa estimasi proses'
                                            : 'Estimasi tidak tersedia')
                                        : 'Estimasi: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(BusinessTime.wallTime(line.estimatedFinishAt!))} WIB',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                Text(
                                    line.isCollected
                                        ? 'Sudah diambil${line.collectedAt == null ? ' · waktu tidak tersedia' : ' · ${DateFormat('dd MMM, HH:mm', 'id_ID').format(BusinessTime.wallTime(line.collectedAt!))} WIB'}'
                                        : line.isReady
                                            ? (line.status == LaundryStatus.late
                                                ? 'Siap diambil · terlambat'
                                                : 'Siap diambil')
                                            : 'Masih diproses',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                if (line.hasProofImage && line.id.isNotEmpty)
                                  _LineProofButton(
                                      transactionId: transaction.id,
                                      detailId: line.id),
                              ])),
                        ])),
              ))
          .toList());
}

class _LineProofButton extends ConsumerWidget {
  const _LineProofButton({required this.transactionId, required this.detailId});
  final String transactionId;
  final String detailId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
        icon: const Icon(Icons.photo_outlined, size: 16),
        label: const Text('Lihat bukti layanan'),
        onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => _LineProofDialog(transactionId, detailId)),
      );
}

class _LineProofDialog extends ConsumerWidget {
  const _LineProofDialog(this.id, this.detailId);
  final String id;
  final String detailId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
          title: const Text('Bukti pengambilan layanan'),
          content: SizedBox(
              width: 400,
              height: 300,
              child:
                  ref.watch(transactionLineProofProvider((id, detailId))).when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const Center(
                            child: Text(
                                'Bukti tidak tersedia atau akses tidak diizinkan.')),
                        data: (bytes) => InteractiveViewer(
                            child: Image.memory(bytes, fit: BoxFit.contain)),
                      )),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'))
          ]);
}
