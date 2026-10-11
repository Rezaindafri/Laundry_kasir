import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_management_system/core/error/failures.dart';
import 'package:laundry_management_system/core/router/app_router.dart';
import 'package:laundry_management_system/core/widgets/page_visibility_refresh.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/mock_transaction_repository.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_page_entity.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/payment_entry_sheet.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';

TransactionEntity _order(
        {int paid = 0,
        bool multiple = false,
        List<TransactionLineEntity>? lines}) =>
    TransactionEntity(
        id: 'a',
        invoice: 'INV-A',
        customerId: 'customer',
        customerName: 'Pelanggan A',
        customerPhone: '',
        serviceName: 'Layanan A',
        quantity: 1,
        quantityUnit: 'item',
        unitPrice: 10000,
        expressFee: 0,
        total: multiple ? 20000 : 10000,
        paidAmount: paid,
        paymentStatus: paid == 0
            ? PaymentStatus.unpaid
            : paid >= (multiple ? 20000 : 10000)
                ? PaymentStatus.paid
                : PaymentStatus.downPayment,
        paymentMethod: PaymentMethod.cash,
        laundryStatus:
            multiple ? LaundryStatus.received : LaundryStatus.completed,
        createdAt: DateTime.utc(2026, 10, 11),
        estimatedFinishAt: DateTime.utc(2026, 10, 11, 2),
        details: lines ??
            [
              const TransactionLineEntity(
                  id: 'line-a',
                  serviceId: 'service-a',
                  name: 'Layanan A',
                  quantity: 1,
                  unit: 'item',
                  unitPrice: 10000,
                  subtotal: 10000,
                  status: LaundryStatus.completed),
              if (multiple)
                const TransactionLineEntity(
                    id: 'line-b',
                    serviceId: 'service-b',
                    name: 'Layanan B',
                    quantity: 1,
                    unit: 'item',
                    unitPrice: 10000,
                    subtotal: 10000,
                    status: LaundryStatus.received),
            ]);

class _Session extends SessionNotifier {
  _Session(this.role);
  final UserRole role;
  @override
  Future<UserEntity?> build() async => UserEntity(
      id: 'actor',
      name: 'Akun uji',
      username: 'fixture',
      role: role,
      isActive: true,
      createdAt: DateTime(2026));
}

class _Repository extends MockTransactionRepository {
  _Repository(this.order);
  TransactionEntity? order;
  bool failRead = false;
  bool failWrite = false;
  final queries = <Map<String, dynamic>>[];
  int writes = 0;
  Future<Result<TransactionPageEntity>> Function(Map<String, dynamic>)? read;

  @override
  Future<Result<List<TransactionEntity>>> getTransactions() async =>
      Success(order == null ? [] : [order!]);

  TransactionPageEntity page(List<TransactionEntity> items,
          {int current = 1, int last = 1}) =>
      TransactionPageEntity(
          items: items,
          currentPage: current,
          lastPage: last,
          total: items.length);

  @override
  Future<Result<TransactionPageEntity>> getTransactionsPage(
      Map<String, dynamic> query) async {
    queries.add(Map.of(query));
    if (read != null) return read!(query);
    if (failRead) return const Error(ServerFailure('Fixture gagal memuat'));
    final current = order;
    return Success(page(current == null ||
            (query['collected'] == 0 &&
                current.laundryStatus == LaundryStatus.collected) ||
            (query['search'] != null &&
                !current.invoice.contains(query['search'] as String))
        ? []
        : [current]));
  }

  @override
  Future<Result<TransactionEntity>> pay({
    required TransactionEntity transaction,
    required int amount,
    required PaymentMethod method,
    String? note,
    required String requestId,
  }) async {
    writes++;
    if (failWrite)
      return const Error(ServerFailure('Fixture pembayaran gagal'));
    final paid = transaction.paidAmount + amount;
    order = transaction.copyWith(
        paidAmount: paid,
        paymentStatus: paid == transaction.total
            ? PaymentStatus.paid
            : PaymentStatus.downPayment);
    return Success(order!);
  }

  @override
  Future<Result<TransactionEntity>> collect({
    required TransactionEntity transaction,
    required bool settlePayment,
    Uint8List? proofImage,
    List<String>? detailIds,
    int? paymentAmount,
    String? paymentNote,
  }) async {
    writes++;
    if (failWrite)
      return const Error(ServerFailure('Fixture pengambilan gagal'));
    final lines = transaction.details
        .map((line) => TransactionLineEntity(
            id: line.id,
            serviceId: line.serviceId,
            name: line.name,
            quantity: line.quantity,
            unit: line.unit,
            unitPrice: line.unitPrice,
            subtotal: line.subtotal,
            status: detailIds!.contains(line.id)
                ? LaundryStatus.collected
                : line.status))
        .toList();
    final paid = transaction.paidAmount + (paymentAmount ?? 0);
    order = _order(
            paid: paid, multiple: transaction.details.length > 1, lines: lines)
        .copyWith(
            laundryStatus: lines.every((line) => line.isCollected)
                ? LaundryStatus.collected
                : LaundryStatus.received);
    return Success(order!);
  }
}

Future<void> _openList(WidgetTester tester, _Repository repository,
    {UserRole role = UserRole.kasir}) async {
  await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider.overrideWith(() => _Session(role)),
        transactionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
          navigatorObservers: [pageRefreshObserver],
          home: const TransactionsScreen(isCollectionMode: true))));
  await tester.pumpAndSettle();
}

Future<void> _payOrCollect(WidgetTester tester,
    {bool collect = false, bool alreadyPaid = false, String? amount}) async {
  await tester.tap(find.text('INV-A').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(collect
      ? alreadyPaid
          ? 'Ambil'
          : 'Bayar & Ambil'
      : 'Bayar Saja'));
  await tester.pumpAndSettle();
  if (amount != null) {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Pembayaran masuk (Rp)'), amount);
  }
  await tester
      .tap(find.text(collect ? 'Konfirmasi Pengambilan' : 'Catat Pembayaran'));
  await tester.pumpAndSettle();
}

Future<void> _pull(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, 400));
  await tester.pumpAndSettle();
}

Future<GoRouter> _openRouted(WidgetTester tester, _Repository repository,
    {required String initialLocation}) async {
  final router = GoRouter(
      initialLocation: initialLocation,
      initialExtra: initialLocation == AppRoutes.collectionSettlement
          ? repository.order
          : null,
      routes: [
        ShellRoute(
            observers: [pageRefreshObserver],
            builder: (_, __, child) => child,
            routes: [
              GoRoute(
                  path: AppRoutes.dashboard,
                  builder: (_, __) =>
                      const Scaffold(body: Text('Beranda uji'))),
              GoRoute(
                  path: AppRoutes.transactions,
                  builder: (_, __) => const TransactionsScreen()),
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
    sessionProvider.overrideWith(() => _Session(UserRole.kasir)),
    transactionRepositoryProvider.overrideWithValue(repository),
  ], child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  for (final role in [UserRole.owner, UserRole.kasir]) {
    for (final collect in [false, true]) {
      testWidgets(
          'successful ${collect ? 'pickup' : 'payment'} returns to fresh search: $role',
          (tester) async {
        final repository = _Repository(_order());
        await _openList(tester, repository, role: role);
        await _payOrCollect(tester, collect: collect);
        expect(find.byType(CollectionSettlementScreen), findsNothing);
        expect(find.text('Pengambilan'), findsOneWidget);
        expect(repository.writes, 1);
        expect(repository.queries.length, 2);
        expect(repository.queries.last['collected'], 0);
        expect(find.text('INV-A'), collect ? findsNothing : findsOneWidget);
        expect(repository.order!.paymentStatus, PaymentStatus.paid);
        if (!collect) expect(find.text('Lunas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'a paid pickup disappears; partial pickup stays with remaining services',
      (tester) async {
    final repository = _Repository(_order(paid: 10000));
    await _openList(tester, repository);
    await _payOrCollect(tester, collect: true, alreadyPaid: true);
    expect(find.text('INV-A'), findsNothing);
    expect(repository.order!.paidAmount, 10000);
    expect(find.byType(CollectionSettlementScreen), findsNothing);

    repository.order = _order(multiple: true);
    await _pull(tester);
    await _payOrCollect(tester, collect: true);
    expect(find.text('INV-A'), findsOneWidget);
    expect(repository.order!.details.first.isCollected, isTrue);
    expect(repository.order!.details.last.isCollected, isFalse);
    expect(repository.order!.paidAmount, 10000);
    expect(find.text('DP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial payment preserves search and refreshes its DP status',
      (tester) async {
    final repository = _Repository(_order());
    await _openList(tester, repository);
    await tester.enterText(find.byType(TextField), 'INV-A');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await _payOrCollect(tester, amount: '3000');
    expect(find.text('DP'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'INV-A');
    expect(repository.queries.last['search'], 'INV-A');
    expect(repository.order!.remainingPayment, 7000);
    expect(find.byType(CollectionSettlementScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final collect in [false, true]) {
    testWidgets(
        'failed ${collect ? 'pickup' : 'payment'} stays on form without pretending success',
        (tester) async {
      final repository = _Repository(_order())..failWrite = true;
      await _openList(tester, repository);
      await _payOrCollect(tester, collect: collect);
      expect(find.byType(CollectionSettlementScreen), findsOneWidget);
      expect(repository.queries.length, 1);
      expect(repository.order!.paidAmount, 0);
      expect(
          find.text(collect
              ? 'Fixture pengambilan gagal'
              : 'Fixture pembayaran gagal'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Back refreshes search; cancelling a payment modal stays on form',
      (tester) async {
    final repository = _Repository(_order());
    await _openList(tester, repository);
    await tester.tap(find.text('INV-A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar Saja'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(PaymentEntrySheet), findsNothing);
    expect(find.byType(CollectionSettlementScreen), findsOneWidget);
    expect(repository.writes, 0);
    repository.order = null; // Another operator finished the order.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Pengambilan'), findsOneWidget);
    expect(find.text('INV-A'), findsNothing);
    expect(repository.queries.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pull refresh works on an empty, short and failed list',
      (tester) async {
    final repository = _Repository(null);
    await _openList(tester, repository);
    repository.order = _order();
    await _pull(tester);
    expect(find.text('INV-A'), findsOneWidget);
    repository.order = null;
    await _pull(tester);
    expect(find.text('INV-A'), findsNothing);
    repository.failRead = true;
    await _pull(tester);
    expect(find.text('Coba lagi'), findsOneWidget);
    repository.failRead = false;
    repository.order = _order();
    await _pull(tester);
    expect(find.text('INV-A'), findsOneWidget);
    expect(repository.queries.length, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a late old page cannot restore a collected transaction after refresh',
      (tester) async {
    final repository = _Repository(_order());
    final oldPage = Completer<Result<TransactionPageEntity>>();
    var refreshed = false;
    repository.read = (query) async {
      if (query['page'] == 2) return oldPage.future;
      return Success(repository.page(refreshed ? [] : [_order()],
          last: refreshed ? 1 : 2));
    };
    await _openList(tester, repository);
    final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
    scroll.jumpTo(scroll.position.maxScrollExtent + 1);
    await tester.pump();
    expect(repository.queries.last['page'], 2);
    refreshed = true;
    final refreshing = tester
        .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
        .show();
    await tester.pumpAndSettle();
    await refreshing;
    oldPage.complete(Success(repository.page([_order()], current: 2, last: 2)));
    await tester.pumpAndSettle();
    expect(find.text('INV-A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a routed settlement reuses and refreshes an existing search page',
      (tester) async {
    final repository = _Repository(_order());
    final router = await _openRouted(tester, repository,
        initialLocation: AppRoutes.collections);
    router.push(AppRoutes.collectionSettlement, extra: repository.order);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar & Ambil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi Pengambilan'));
    await tester.pumpAndSettle();
    expect(find.text('Pengambilan'), findsOneWidget);
    expect(find.text('INV-A'), findsNothing);
    expect(router.state.matchedLocation, AppRoutes.collections);
    expect(router.canPop(), isFalse); // No duplicate search page.
    expect(repository.queries.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'payment from transaction detail removes temporary pages and keeps originating tab',
      (tester) async {
    final repository = _Repository(_order());
    final router = await _openRouted(tester, repository,
        initialLocation: AppRoutes.transactions);
    await tester.tap(find.text('INV-A'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailScreen), findsOneWidget);
    final action = find.text('Pengambilan / Pembayaran');
    await tester.scrollUntilVisible(action, 250,
        scrollable: find
            .descendant(
                of: find.byType(TransactionDetailScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(action);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bayar Saja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Catat Pembayaran'));
    await tester.pumpAndSettle();
    expect(find.text('Pengambilan'), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);
    expect(find.byType(CollectionSettlementScreen), findsNothing);
    expect(find.byType(TransactionDetailScreen), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, AppRoutes.transactions);
    expect(find.text('Transaksi'), findsOneWidget);
    expect(find.text('Lunas'), findsOneWidget);
    expect(find.byType(TransactionDetailScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final direct in [false, true]) {
    testWidgets(
        'routed QR/direct settlement returns to search without reopening finished detail: $direct',
        (tester) async {
      final repository = _Repository(_order());
      final router = await _openRouted(tester, repository,
          initialLocation:
              direct ? AppRoutes.collectionSettlement : AppRoutes.dashboard);
      if (!direct) {
        router.push(AppRoutes.collectionSettlement, extra: repository.order);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Bayar & Ambil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konfirmasi Pengambilan'));
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, AppRoutes.collections);
      expect(find.byType(CollectionSettlementScreen), findsNothing);
      expect(find.text('INV-A'), findsNothing);
      if (!direct) {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Beranda uji'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
