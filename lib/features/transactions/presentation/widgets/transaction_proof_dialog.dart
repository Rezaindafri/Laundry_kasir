import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_providers.dart';

/// Bytes are downloaded with the API's Bearer interceptor, never a public URL
/// or a token in the URL. The auto-disposed provider follows the active session.
class TransactionProofDialog extends ConsumerWidget {
  const TransactionProofDialog({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
        title: const Text('Bukti pengambilan'),
        content: SizedBox(
          width: 480,
          height: 320,
          child: ref.watch(transactionProofProvider(transactionId)).when(
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
                        onPressed: () => ref.invalidate(
                          transactionProofProvider(transactionId),
                        ),
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
