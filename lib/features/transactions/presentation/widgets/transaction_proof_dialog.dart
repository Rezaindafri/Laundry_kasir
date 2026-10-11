import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_providers.dart';

/// Bytes are downloaded with the API's Bearer interceptor, never a public URL
/// or a token in the URL. The auto-disposed provider follows the active session.
class TransactionProofDialog extends ConsumerWidget {
  const TransactionProofDialog({required this.transactionId, this.detailId, super.key});

  final String transactionId;
  final String? detailId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
        title: const Text('Bukti pengambilan'),
        content: SizedBox(
          width: 480,
          height: 320,
          child: (detailId == null ? ref.watch(transactionProofProvider(transactionId))
              : ref.watch(transactionLineProofProvider((transactionId, detailId!)))).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bukti tidak tersedia atau akses tidak diizinkan.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () {
                          if (detailId == null) ref.invalidate(transactionProofProvider(transactionId));
                          else ref.invalidate(transactionLineProofProvider((transactionId, detailId!)));
                        },
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
                data: (bytes) => InteractiveViewer(
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Text('Bukti tidak dapat ditampilkan.'),
                    ),
                  ),
                ),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      );
}
