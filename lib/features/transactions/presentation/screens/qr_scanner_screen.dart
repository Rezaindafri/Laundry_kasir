import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/router/app_router.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';
import 'transactions_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});
  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final invoice =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (invoice == null || invoice.isEmpty) return;
    TransactionEntity? transaction;
    for (final item in ref.read(transactionsProvider).valueOrNull ?? []) {
      if (item.invoice == invoice) {
        transaction = item;
        break;
      }
    }
    if (transaction == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Transaksi dengan kode tersebut tidak ditemukan.'),),);
      return;
    }
    _handled = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CollectionSettlementScreen(transaction: transaction!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) context.go(AppRoutes.dashboard);
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Scan Kode Pengambilan')),
          body: Stack(children: [
          MobileScanner(onDetect: _onDetect),
          Center(
              child: Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(20),),),),
          const Positioned(
              left: 24,
              right: 24,
              bottom: 44,
              child: Text('Arahkan kamera ke QR pada bon laundry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600,),),),
          ],),
        ),
      );
}
