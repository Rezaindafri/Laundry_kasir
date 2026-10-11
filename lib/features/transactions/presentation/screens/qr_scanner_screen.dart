import 'dart:async';

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

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver, RouteAware {
  final _scannerController = MobileScannerController();
  final _imagePicker = ImagePicker();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;
  bool _leaving = false;
  bool _handled = false;
  bool _loadingTransaction = false;
  bool _analyzingGallery = false;
  ModalRoute<dynamic>? _observedRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _observedRoute) return;
    appRouteObserver.unsubscribe(this);
    _observedRoute = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  Future<void> _resumeScanner() async {
    if (!_isCurrent || _handled) return;
    try {
      await _scannerController.start();
    } catch (_) {
      // The preview already displays camera/permission errors from the plugin.
    }
  }

  @override
  void didPushNext() => unawaited(_stopScanner());

  @override
  void didPopNext() => unawaited(_resumeScanner());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeScanner());
    } else {
      unawaited(_stopScanner());
    }
  }

  bool get _isCurrent =>
      mounted &&
      !_leaving &&
      !_drawerOpen &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop().timeout(const Duration(seconds: 2));
    } catch (_) {
      // A camera stop error must not block Back or opening the transaction.
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !_isCurrent) return;
    final invoice =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (invoice == null || invoice.isEmpty) return;
    _openTransaction(invoice);
  }

  Future<void> _scanFromGallery() async {
    if (_handled || _analyzingGallery || !_isCurrent) return;
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null || !_isCurrent) return;

    setState(() => _analyzingGallery = true);
    try {
      final capture = await _scannerController.analyzeImage(image.path);
      if (!_isCurrent) return;
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
    if (_handled || _loadingTransaction || !_isCurrent) return;
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
    if (!_isCurrent) {
      if (mounted && !_leaving) setState(() => _loadingTransaction = false);
      return;
    }
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
    await _stopScanner();
    if (!_isCurrent) {
      if (mounted && !_leaving)
        setState(() {
          _handled = false;
          _loadingTransaction = false;
        });
      return;
    }
    _leaving = true;
    context.pushReplacement(
      AppRoutes.collectionSettlement,
      extra: transaction,
    );
  }

  @override
  void dispose() {
    _leaving = true;
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider).valueOrNull;
    return PopScope(
      canPop: _drawerOpen || GoRouter.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Closing a drawer's LocalHistoryEntry is not leaving this page.
          if (ModalRoute.of(context)?.isCurrent != true) {
            _leaving = true;
            unawaited(_stopScanner());
          }
          return;
        }
        if (_drawerOpen) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        _leaving = true;
        unawaited(_stopScanner());
        // Direct entry has no previous page; return to the app's home only then.
        context.go(AppRoutes.dashboard);
      },
      child: Scaffold(
        key: _scaffoldKey,
        onDrawerChanged: (open) => setState(() => _drawerOpen = open),
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
            MobileScanner(controller: _scannerController, onDetect: _onDetect),
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
