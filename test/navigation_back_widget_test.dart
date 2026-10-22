import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/mobile_scanner_platform_interface.dart';
import 'package:mobile_scanner/src/mobile_scanner_view_attributes.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:laundry_management_system/core/error/failures.dart';
import 'package:laundry_management_system/core/router/app_router.dart';
import 'package:laundry_management_system/core/widgets/navigation_write_guard.dart';
import 'package:laundry_management_system/core/widgets/safe_modal_sheet.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/data/models/user_model.dart';
import 'package:laundry_management_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_management_system/features/dashboard/presentation/widgets/dashboard_shell.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/master_data/data/repositories/mock_master_data_repository.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/customer_entity.dart';
import 'package:laundry_management_system/features/master_data/presentation/providers/master_data_providers.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/laundry_service_entity.dart';
import 'package:laundry_management_system/features/master_data/presentation/screens/customers_screen.dart';
import 'package:laundry_management_system/features/master_data/presentation/screens/laundry_services_screen.dart';
import 'package:laundry_management_system/features/settings/domain/entities/laundry_settings.dart';
import 'package:laundry_management_system/features/settings/presentation/providers/settings_providers.dart';
import 'package:laundry_management_system/features/settings/presentation/screens/settings_screen.dart';
import 'package:laundry_management_system/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:laundry_management_system/features/user_management/presentation/providers/user_management_providers.dart';
import 'package:laundry_management_system/features/user_management/presentation/screens/user_management_screen.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/mock_transaction_repository.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_page_entity.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/qr_scanner_screen.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/transactions_screen.dart';

class _MasterFixture extends MockMasterDataRepository {
  int saves = 0;
  Completer<Result<CustomerEntity>>? pendingSave;

  @override
  Future<Result<List<CustomerEntity>>> getCustomers() async =>
      const Success([]);

  @override
  Future<Result<List<LaundryServiceEntity>>> getServices() async =>
      const Success([
        LaundryServiceEntity(
            id: 'service',
            name: 'Barang uji',
            price: 10000,
            unit: 'item',
            estimatedHours: 0),
      ]);

  @override
  Future<Result<CustomerEntity>> saveCustomer(CustomerEntity customer) async {
    saves++;
    if (pendingSave != null) return pendingSave!.future;
    return Success(CustomerEntity(id: 'saved', name: customer.name));
  }
}

UserEntity _user(UserRole role) => UserEntity(
    id: 'fixture',
    name: 'Uji',
    username: 'uji',
    role: role,
    isActive: true,
    createdAt: DateTime(2026));

class _AuthFixture implements AuthRepository {
  _AuthFixture(this.user);
  final UserEntity user;
  @override
  Future<Result<UserEntity?>> getCurrentUser() async => Success(user);
  @override
  Future<bool> hasActiveSession() async => true;
  @override
  Future<Result<void>> logout() async => const Success(null);
  @override
  Future<Result<UserEntity>> login(
          {required String username,
          required String password,
          required bool rememberMe}) async =>
      Success(user);
}

class _SettingsFixture extends LaundrySettingsNotifier {
  @override
  Future<LaundrySettings> build() async => const LaundrySettings(
      businessName: 'Usaha uji', phone: '', address: '', paperSize: '58 mm');
}

class _UsersFixture implements UserManagementRepository {
  @override
  Future<Result<List<UserEntity>>> getUsers() async =>
      Success([_user(UserRole.kasir)]);
  @override
  Future<Result<UserEntity>> saveUser(UserEntity user,
          {String? password}) async =>
      const Error(ServerFailure('Tidak boleh menyimpan fixture ini'));
  @override
  Future<Result<UserEntity>> updateCredentials(
          {required UserEntity user,
          required String managerUsername,
          required String managerPassword,
          required String name,
          required String username,
          String? password}) async =>
      const Error(ServerFailure('Tidak boleh menyimpan fixture ini'));
  @override
  Future<Result<UserEntity>> toggleUserStatus(String id) async =>
      const Error(ServerFailure('Tidak boleh menyimpan fixture ini'));
}

TransactionEntity _transaction() => TransactionEntity(
    id: 'order',
    invoice: 'INV-UJI',
    customerId: 'customer',
    serviceId: 'service',
    customerName: 'Pelanggan uji',
    customerPhone: '',
    serviceName: 'Barang uji',
    quantity: 1,
    quantityUnit: 'item',
    unitPrice: 10000,
    expressFee: 0,
    total: 10000,
    paidAmount: 0,
    paymentMethod: PaymentMethod.cash,
    paymentStatus: PaymentStatus.unpaid,
    laundryStatus: LaundryStatus.completed,
    createdAt: DateTime(2026),
    estimatedFinishAt: DateTime(2026));

class _TransactionsFixture extends MockTransactionRepository {
  Completer<Result<TransactionEntity>>? pendingWrite;
  Completer<Result<TransactionPageEntity>>? pendingLookup;
  int writes = 0;
  @override
  Future<Result<List<TransactionEntity>>> getTransactions() async =>
      const Success([]);
  @override
  Future<Result<TransactionEntity>> create(
      TransactionEntity transaction) async {
    writes++;
    return pendingWrite!.future;
  }

  @override
  Future<Result<TransactionPageEntity>> getTransactionsPage(
      Map<String, dynamic> filters) async {
    if (pendingLookup != null) return pendingLookup!.future;
    return Success(TransactionPageEntity(
        items: [_transaction()], currentPage: 1, lastPage: 1, total: 1));
  }

  @override
  Future<Result<TransactionEntity>> pay(
      {required TransactionEntity transaction,
      required int amount,
      required PaymentMethod method,
      String? note,
      required String requestId}) async {
    writes++;
    return pendingWrite!.future;
  }

  @override
  Future<Result<TransactionEntity>> collect(
      {required TransactionEntity transaction,
      required bool settlePayment,
      Uint8List? proofImage,
      List<String>? detailIds,
      int? paymentAmount,
      String? paymentNote}) async {
    writes++;
    return pendingWrite!.future;
  }
}

class _ScannerFixture extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  int starts = 0;
  int stops = 0;
  int disposals = 0;
  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.blue);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    return const MobileScannerViewAttributes(
        currentTorchMode: TorchState.off,
        size: Size(400, 600),
        numberOfCameras: 1);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {
    disposals++;
  }
}

Future<GoRouter> _shell(WidgetTester tester,
    {UserRole role = UserRole.kasir,
    String initialLocation = AppRoutes.dashboard,
    _MasterFixture? master,
    _TransactionsFixture? transactions}) async {
  final user = _user(role);
  Widget page(String title) => Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: AppNavigationDrawer(user: user),
      body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Builder(
            builder: (context) => TextButton(
                onPressed: () =>
                    context.push('${AppRoutes.customers}?create=true'),
                child: const Text('Aksi pelanggan'))),
        Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            const Scaffold(body: Text('Detail uji')))),
                child: const Text('Buka detail'))),
      ])));
  final router = GoRouter(initialLocation: initialLocation, routes: [
    ShellRoute(
        observers: [appRouteObserver],
        builder: (_, __, child) => PersistentTabShell(child: child),
        routes: [
          GoRoute(
              path: AppRoutes.dashboard,
              builder: (_, __) => page('Beranda uji')),
          GoRoute(
              path: AppRoutes.transactions,
              builder: (_, __) => page('Transaksi uji')),
          GoRoute(
              path: AppRoutes.settings,
              builder: (_, __) => page('Setting uji')),
          GoRoute(
              path: AppRoutes.reports, builder: (_, __) => page('Laporan uji')),
          GoRoute(path: AppRoutes.users, builder: (_, __) => page('Akun uji')),
          GoRoute(
              path: AppRoutes.customers,
              builder: (_, state) => CustomersScreen(
                  key: ValueKey(state.uri.toString()),
                  openCreateForm:
                      state.uri.queryParameters['create'] == 'true')),
          GoRoute(
              path: AppRoutes.qrScanner,
              builder: (_, __) => const QrScannerScreen()),
          GoRoute(
              path: AppRoutes.collections,
              builder: (_, __) =>
                  const TransactionsScreen(isCollectionMode: true)),
          GoRoute(
              path: AppRoutes.collectionSettlement,
              builder: (_, state) => CollectionSettlementScreen(
                  transaction: state.extra! as TransactionEntity)),
        ]),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    authRepositoryProvider.overrideWithValue(_AuthFixture(user)),
    masterDataRepositoryProvider.overrideWithValue(master ?? _MasterFixture()),
    transactionRepositoryProvider
        .overrideWithValue(transactions ?? _TransactionsFixture()),
  ], child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void _mockScanner() {
  final original = MobileScannerPlatform.instance;
  final scanner = _ScannerFixture();
  MobileScannerPlatform.instance = scanner;
  addTearDown(() async {
    MobileScannerPlatform.instance = original;
    await scanner.captures.close();
  });
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('inline customer popup closes on Back without controller errors',
      (tester) async {
    final repository = _MasterFixture();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentSessionUserIdProvider.overrideWithValue('fixture'),
        masterDataRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: NewTransactionScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah pelanggan baru'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find
            .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(TextFormField))
            .first,
        'Tidak disimpan');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Batalkan perubahan?'), findsOneWidget);
    await tester.tap(find.text('Ya, batalkan'));
    await tester.pumpAndSettle();
    expect(find.text('Pelanggan Baru'), findsNothing);
    expect(find.byType(NewTransactionScreen), findsOneWidget);
    expect(repository.saves, 0);
    expect(tester.takeException(), isNull);
  });

  for (final mode in ['Back', 'outside', 'submit']) {
    testWidgets('safe sheet keeps controllers until fully dismissed: $mode',
        (tester) async {
      final controller = TextEditingController();
      var returned = false;
      String? value;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () async {
                        value = await showSafeModalBottomSheet<String>(
                            context: context,
                            controllers: [controller],
                            builder: (sheetContext) => Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(controller: controller),
                                      TextButton(
                                          onPressed: () => Navigator.pop(
                                              sheetContext, controller.text),
                                          child: const Text('Simpan uji'))
                                    ])));
                        returned = true;
                      },
                      child: const Text('Buka'))))));
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Nilai uji');
      if (mode == 'Back') {
        await tester.binding.handlePopRoute();
      } else if (mode == 'outside') {
        await tester.tapAt(const Offset(10, 30));
      } else {
        await tester.tap(find.text('Simpan uji'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      expect(returned, isFalse);
      void listener() {}
      controller.addListener(listener); // must still be alive in reverse
      controller.removeListener(listener);
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(value, mode == 'submit' ? 'Nilai uji' : null);
      expect(() => controller.addListener(listener), throwsAssertionError);
      expect(tester.takeException(), isNull);
    });
  }

  for (final role in UserRole.values) {
    testWidgets('tab Back retains history and exit is home-only: ${role.name}',
        (tester) async {
      await _shell(tester, role: role);
      final first = role == UserRole.superOwner ? 'Akun' : 'Transaksi';
      final pageTitle =
          role == UserRole.superOwner ? 'Akun uji' : 'Transaksi uji';
      await tester.tap(find.text(first));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Setting'));
      await tester.pumpAndSettle();
      await _back(tester);
      expect(find.text(pageTitle), findsOneWidget);
      expect(find.text('Keluar aplikasi?'), findsNothing);
      await _back(tester);
      expect(find.text('Beranda uji'), findsOneWidget);
      await _back(tester);
      expect(find.text('Keluar aplikasi?'), findsOneWidget);
      await _back(tester); // close the dialog, not the app
      expect(find.text('Keluar aplikasi?'), findsNothing);
      expect(find.text('Beranda uji'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('drawer closes before going back one tab', (tester) async {
    await _shell(tester);
    await tester.tap(find.text('Transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsOneWidget);
    await _back(tester);
    expect(find.text('Pengaturan'), findsNothing);
    expect(find.text('Setting uji'), findsOneWidget);
    await _back(tester);
    expect(find.text('Transaksi uji'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('imperative detail page returns to originating tab',
      (tester) async {
    await _shell(tester);
    await tester.tap(find.text('Transaksi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka detail'));
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.text('Transaksi uji'), findsOneWidget);
    expect(find.text('Keluar aplikasi?'), findsNothing);
  });

  testWidgets('direct tab entry returns home before offering exit',
      (tester) async {
    await _shell(tester, initialLocation: AppRoutes.settings);
    await _back(tester);
    expect(find.text('Beranda uji'), findsOneWidget);
    expect(find.text('Keluar aplikasi?'), findsNothing);
  });

  for (final save in [false, true]) {
    testWidgets(
        'quick customer form preserves origin after ${save ? 'save' : 'Back'}',
        (tester) async {
      final master = _MasterFixture();
      await _shell(tester, master: master);
      await tester.tap(find.text('Aksi pelanggan'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Uji cepat');
      if (save) {
        await tester.tap(find.text('Simpan'));
        await tester.pumpAndSettle();
      } else {
        await _back(tester);
        expect(find.text('Batalkan perubahan?'), findsOneWidget);
        await tester.tap(find.text('Ya, batalkan'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Pelanggan Baru'), findsNothing);
      expect(find.byType(CustomersScreen), findsOneWidget);
      expect(master.saves, save ? 1 : 0);
      await _back(tester);
      expect(find.text('Beranda uji'), findsOneWidget);
      expect(find.text('Keluar aplikasi?'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Back and tab switching wait for customer save result',
      (tester) async {
    final master = _MasterFixture()..pendingSave = Completer();
    await _shell(tester, master: master);
    await tester.tap(find.text('Aksi pelanggan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Uji tertunda');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.byType(CustomersScreen), findsOneWidget);
    expect(find.text(savingNavigationMessage), findsOneWidget);
    await tester.tap(find.text('Setting'), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(CustomersScreen), findsOneWidget);
    master.pendingSave!.complete(const Error(ServerFailure('Uji gagal')));
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.text('Beranda uji'), findsOneWidget);
    expect(master.saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scanner Back closes drawer then returns to its originating tab',
      (tester) async {
    _mockScanner();
    final scanner = MobileScannerPlatform.instance as _ScannerFixture;
    await _shell(tester);
    await tester.tap(find.text('Setting'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.pumpAndSettle();
    expect(tester.widget<MobileScanner>(find.byType(MobileScanner)).controller,
        isNotNull);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.byType(QrScannerScreen), findsOneWidget);
    await _back(tester);
    expect(find.text('Setting uji'), findsOneWidget);
    expect(find.text('Keluar aplikasi?'), findsNothing);
    expect(scanner.disposals, 1);
    expect(scanner.stops, greaterThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct scanner entry closes drawer then falls back to home',
      (tester) async {
    _mockScanner();
    await _shell(tester, initialLocation: AppRoutes.qrScanner);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await _back(tester);
    expect(find.byType(QrScannerScreen), findsOneWidget);
    await _back(tester);
    expect(find.text('Beranda uji'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late QR lookup cannot navigate after Back', (tester) async {
    _mockScanner();
    final repository = _TransactionsFixture()..pendingLookup = Completer();
    final router = await _shell(tester, transactions: repository);
    router.push(AppRoutes.qrScanner);
    await tester.pumpAndSettle();
    tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
        const BarcodeCapture(barcodes: [Barcode(rawValue: 'INV-UJI')]));
    await tester.pump();
    await _back(tester);
    repository.pendingLookup!.complete(Success(TransactionPageEntity(
        items: [_transaction()], currentPage: 1, lastPage: 1, total: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Beranda uji'), findsOneWidget);
    expect(find.byType(CollectionSettlementScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final collect in [false, true]) {
    testWidgets('Back waits for ${collect ? 'collection' : 'payment'} result',
        (tester) async {
      final repository = _TransactionsFixture()..pendingWrite = Completer();
      final router = await _shell(tester, transactions: repository);
      router.push(AppRoutes.collectionSettlement, extra: _transaction());
      await tester.pumpAndSettle();
      await tester.tap(find.text(collect ? 'Bayar & Ambil' : 'Bayar Saja'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.tap(
          find.text(collect ? 'Konfirmasi Pengambilan' : 'Catat Pembayaran'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(CollectionSettlementScreen), findsOneWidget);
      expect(find.text(savingNavigationMessage), findsOneWidget);
      expect(repository.writes, 1);
      repository.pendingWrite!.complete(Success(_transaction().copyWith(
          paidAmount: 10000,
          paymentStatus: PaymentStatus.paid,
          laundryStatus:
              collect ? LaundryStatus.collected : LaundryStatus.completed)));
      await tester.pumpAndSettle();
      expect(find.text('Pengambilan'), findsOneWidget);
      expect(find.byType(CollectionSettlementScreen), findsNothing);
      await _back(tester);
      expect(find.text('Beranda uji'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('write lock is released after an exception', (tester) async {
    final pending = Completer<void>();
    Future<void>? operation;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: Consumer(
                builder: (context, ref, _) => NavigationWriteGuard(
                    child: Scaffold(
                        body: TextButton(
                            onPressed: () {
                              operation = withNavigationWriteLock(
                                  ref, () => pending.future);
                              operation!.catchError((Object _) {});
                            },
                            child: Text(
                                '${ref.watch(navigationWritesProvider)} pending'))))))));
    await tester.tap(find.text('0 pending'));
    await tester.pump();
    expect(find.text('1 pending'), findsOneWidget);
    pending.completeError(StateError('Fixture failure'));
    await tester.pumpAndSettle();
    expect(find.text('0 pending'), findsOneWidget);
    expect(operation, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final success in [false, true]) {
    testWidgets(
        'new order blocks Back while saving then permits ${success ? 'detail' : 'return'}',
        (tester) async {
      final repository = _TransactionsFixture()..pendingWrite = Completer();
      await _shell(tester, transactions: repository);
      Navigator.of(tester.element(find.text('Beranda uji'))).push(
          MaterialPageRoute<void>(
              builder: (_) => const NewTransactionScreen(
                  initialCustomer:
                      CustomerEntity(id: 'customer', name: 'Pelanggan uji'))));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('transaction-service-picker-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Barang uji'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('transaction-service-quantity-0')), '1');
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(NewTransactionScreen), findsOneWidget);
      expect(find.text(savingNavigationMessage), findsOneWidget);
      expect(repository.writes, 1);
      repository.pendingWrite!.complete(success
          ? Success(_transaction())
          : const Error(ServerFailure('Uji gagal')));
      await tester.pumpAndSettle();
      if (success) {
        expect(find.byType(TransactionDetailScreen), findsOneWidget);
        expect(find.byType(NewTransactionScreen), findsNothing);
      }
      await _back(tester);
      if (!success) {
        expect(find.text('Batalkan perubahan?'), findsOneWidget);
        await tester.tap(find.text('Ya, batalkan'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Beranda uji'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final status in [LaundryStatus.received, LaundryStatus.collected]) {
    testWidgets(
        'scanner replacement preserves origin even for ${status.name} order',
        (tester) async {
      _mockScanner();
      final repository = _TransactionsFixture()..pendingLookup = Completer();
      final router = await _shell(tester, transactions: repository);
      await tester.tap(find.text('Setting'));
      await tester.pumpAndSettle();
      router.push(AppRoutes.qrScanner);
      await tester.pumpAndSettle();
      tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
          const BarcodeCapture(barcodes: [Barcode(rawValue: 'INV-UJI')]));
      repository.pendingLookup!.complete(Success(TransactionPageEntity(
          items: [_transaction().copyWith(laundryStatus: status)],
          currentPage: 1,
          lastPage: 1,
          total: 1)));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionSettlementScreen), findsOneWidget);
      await _back(tester);
      expect(find.text('Setting uji'), findsOneWidget);
      expect(find.byType(QrScannerScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'scanner pauses in background and when covered, resumes on return',
      (tester) async {
    _mockScanner();
    final scanner = MobileScannerPlatform.instance as _ScannerFixture;
    final router = await _shell(tester);
    router.push(AppRoutes.qrScanner);
    await tester.pumpAndSettle();
    final initialStarts = scanner.starts;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(scanner.stops, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(scanner.starts, initialStarts + 1);
    router.push(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(scanner.stops, 2);
    await _back(tester);
    expect(find.byType(QrScannerScreen), findsOneWidget);
    expect(scanner.starts, initialStarts + 2);
    await _back(tester);
    expect(tester.takeException(), isNull);
  });

  for (final form in [
    'service',
    'profile',
    'password',
    'account',
    'credentials'
  ]) {
    testWidgets('Back safely dismisses the real $form form', (tester) async {
      final owner = _user(UserRole.owner);
      final screen = form == 'service'
          ? const LaundryServicesScreen()
          : ['profile', 'password'].contains(form)
              ? const SettingsScreen()
              : const UserManagementScreen();
      await tester.pumpWidget(ProviderScope(overrides: [
        authRepositoryProvider.overrideWithValue(_AuthFixture(owner)),
        masterDataRepositoryProvider.overrideWithValue(_MasterFixture()),
        laundrySettingsProvider.overrideWith(_SettingsFixture.new),
        currentProfileProvider
            .overrideWith((ref) async => UserModel.fromEntity(owner)),
        accountPasswordMinLengthProvider.overrideWith((ref) async => 6),
        userManagementRepositoryProvider.overrideWithValue(_UsersFixture()),
      ], child: MaterialApp(home: screen)));
      await tester.pumpAndSettle();
      if (form == 'service' || form == 'account') {
        await tester.tap(find.text('Tambah'));
      } else if (form == 'profile') {
        await tester.tap(find.text('Ubah profil'));
      } else if (form == 'password') {
        await tester.tap(find.text('Ganti password'));
      } else {
        await tester.tap(find.widgetWithText(ListTile, '@uji • Kasir'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Kelola kredensial'));
        await tester.tap(find.text('Kelola kredensial'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      final fields = find.descendant(
          of: find.byType(BottomSheet), matching: find.byType(TextFormField));
      await tester.enterText(fields.first, 'Uji modal');
      await _back(tester);
      expect(find.text('Batalkan perubahan?'), findsOneWidget);
      await tester.tap(find.text('Ya, batalkan'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
