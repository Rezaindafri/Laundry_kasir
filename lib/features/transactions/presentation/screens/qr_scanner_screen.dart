import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dashboard/presentation/widgets/dashboard_shell.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/transaction_providers.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});
  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final _scannerController = MobileScannerController();
  final _imagePicker = ImagePicker();
  bool _handled = false;
  bool _loadingTransaction = false;
  bool _analyzingGallery = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final invoice =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (invoice == null || invoice.isEmpty) return;
    _openTransaction(invoice);
  }

  Future<void> _scanFromGallery() async {
    if (_handled || _analyzingGallery) return;
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _analyzingGallery = true);
    try {
      final capture = await _scannerController.analyzeImage(image.path);
      if (!mounted) return;
      final invoice = capture?.barcodes.isEmpty == false
          ? capture!.barcodes.first.rawValue
          : null;
      if (invoice == null || invoice.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR tidak ditemukan pada gambar.')),
        );
        return;
      }
      _openTransaction(invoice);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gambar tidak dapat dipindai.')),
      );
    } finally {
      if (mounted) setState(() => _analyzingGallery = false);
    }
  }

  Future<void> _openTransaction(String invoice) async {
    if (_handled || _loadingTransaction) return;
    // Receipts encode only the invoice, but accepting the invoice embedded in
    // copied/legacy QR text makes this lookup resilient to scanner formatting.
    final invoiceMatch =
        RegExp(r'INV-[A-Z0-9-]+', caseSensitive: false).firstMatch(invoice);
    final normalizedInvoice = (invoiceMatch?.group(0) ?? invoice).trim();
    if (normalizedInvoice.isEmpty) return;
    setState(() => _loadingTransaction = true);
    final result =
        await ref.read(transactionRepositoryProvider).getTransactionsPage({
      'invoice': normalizedInvoice,
      'per_page': 1,
    });
    if (!mounted) return;
    TransactionEntity? transaction;
    var requestFailed = false;
    result.when(
      success: (page) {
        // The server already performs an exact invoice lookup. Accept its
        // returned record so a harmless scanner normalization does not block
        // navigation to the transaction screen.
        if (page.items.isNotEmpty) transaction = page.items.first;
      },
      error: (failure) {
        requestFailed = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
    if (requestFailed) {
      setState(() => _loadingTransaction = false);
      return;
    }
    if (transaction == null) {
      setState(() => _loadingTransaction = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Transaksi dengan kode tersebut tidak ditemukan.'),
      ));
      return;
    }
    _handled = true;
    // Release the Android camera before removing its texture. A device-specific
    // stop failure must not prevent the cashier from opening the transaction.
    try {
      await _scannerController.stop().timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.pushReplacement(
        AppRoutes.collectionSettlement,
        extra: transaction,
      );
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(AppRoutes.dashboard);
      },
      child: Scaffold(
        drawer: user == null ? null : AppNavigationDrawer(user: user),
        appBar: AppBar(
          title: const Text('Scan Kode Pengambilan'),
          actions: [
            IconButton(
              onPressed: _analyzingGallery ? null : _scanFromGallery,
              tooltip: 'Pilih gambar dari galeri',
              icon: _analyzingGallery
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_library_outlined),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(onDetect: _onDetect),
            Center(
              child: Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const Positioned(
              left: 24,
              right: 24,
              bottom: 44,
              child: Text(
                'Arahkan kamera ke QR pada bon laundry.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
