import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_management_system/core/error/failures.dart';
import 'package:laundry_management_system/core/network/dio_client.dart';
import 'package:laundry_management_system/core/router/active_page_refresh.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/core/widgets/page_visibility_refresh.dart';
import 'package:laundry_management_system/features/audit/presentation/providers/audit_refresh_provider.dart';
import 'package:laundry_management_system/features/audit/presentation/screens/audit_logs_screen.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/dashboard/data/models/dashboard_owner_model.dart';
import 'package:laundry_management_system/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:laundry_management_system/features/transactions/data/models/transaction_model.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/mock_transaction_repository.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';

class _Owner extends SessionNotifier {
  @override
  Future<UserEntity?> build() async => UserEntity(
      id: 'owner-a',
      name: 'Owner A',
      username: 'fixture',
      role: UserRole.owner,
      isActive: true,
      createdAt: DateTime(2026));
}

class _Dashboard extends OwnerDashboardNotifier {
  @override
  Future<DashboardOwnerResponse> build() async =>
      DashboardOwnerResponse.fromJson({});
}

class _Repository extends MockTransactionRepository {
  bool fail = false;
  @override
  Future<Result<TransactionEntity>> completeService(
          String id, String detailId) async =>
      fail
          ? const Error(ServerFailure('Fixture gagal'))
          : Success(TransactionModel.fromJson({
              'id': 1,
              'invoice_number': 'INV-1',
              'created_at': '2026-11-20T07:00:00Z',
            }).toEntity());
}

const _row = {
  'action': 'transaction.deleted',
  'subject_type': 'transaction',
  'subject_id': 1,
  'created_at': '2026-11-20T07:00:00Z',
  'metadata': {
    'actor_snapshot': {
      'id': 2,
      'name': 'Sari',
      'username': 'sari',
      'role': 'kasir'
    },
    'before': {'invoice_number': 'INV-1'},
    'reason': 'Bon ganda',
  },
};

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  void intercept(dynamic Function(RequestOptions) response) {
    final dio = DioClient().dio;
    final interceptor = InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/audit-logs');
      handler.resolve(Response(
          requestOptions: options, statusCode: 200, data: response(options)));
    });
    dio.interceptors.add(interceptor);
    addTearDown(() => dio.interceptors.remove(interceptor));
  }

  ProviderContainer container({_Repository? repository}) =>
      ProviderContainer(overrides: [
        sessionProvider.overrideWith(_Owner.new),
        currentSessionUserIdProvider.overrideWithValue('owner-a'),
        ownerDashboardProvider.overrideWith(_Dashboard.new),
        transactionRepositoryProvider
            .overrideWithValue(repository ?? _Repository()),
      ]);

  for (final malformed in [
    <String, dynamic>{},
    {'data': 'not-a-list'},
    {
      'data': [42]
    },
    {
      'data': [
        {'action': 'transaction.deleted'}
      ]
    }
  ]) {
    testWidgets(
        'malformed audit is an error with retry, not an empty history: $malformed',
        (tester) async {
      var broken = true;
      intercept((_) => broken ? malformed : {'data': []});
      final scope = container();
      addTearDown(scope.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: scope,
          child: MaterialApp(
              home: Scaffold(body: CashierActivityCard(onOpen: () {})))));
      await tester.pumpAndSettle();
      expect(find.text('Aktivitas gagal dimuat.'), findsOneWidget);
      expect(find.text('Belum ada aktivitas kasir.'), findsNothing);
      broken = false;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada aktivitas kasir.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('audit timestamp and details explicitly use WIB', (tester) async {
    intercept((_) => {
          'data': [_row]
        });
    final scope = container();
    addTearDown(scope.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope, child: const MaterialApp(home: AuditLogsScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('20 Nov 2026, 14:00 WIB'), findsOneWidget);
    await tester.tap(find.text('Transaksi dihapus'));
    await tester.pumpAndSettle();
    expect(find.text('Alasan: Bon ganda'), findsWidgets);
    expect(find.textContaining('20 Nov 2026, 14:00 WIB'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('full audit error has a usable retry control', (tester) async {
    var broken = true;
    intercept((_) => broken
        ? {'data': null}
        : {
            'data': [_row]
          });
    final scope = container();
    addTearDown(scope.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope, child: const MaterialApp(home: AuditLogsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat riwayat.'), findsOneWidget);
    broken = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi dihapus'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'successful service mutation refreshes cashier activity; failed mutation does not',
      (tester) async {
    var reads = 0;
    intercept((_) {
      reads++;
      return {
        'data': reads == 1 ? [] : [_row]
      };
    });
    final repository = _Repository();
    final scope = container(repository: repository);
    addTearDown(scope.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
            home: Scaffold(body: CashierActivityCard(onOpen: () {})))));
    await tester.pumpAndSettle();
    await scope.read(transactionsProvider.future);
    repository.fail = true;
    await scope.read(transactionsProvider.notifier).completeService('1', '1');
    await tester.pumpAndSettle();
    expect(reads, 1);
    repository.fail = false;
    await scope.read(transactionsProvider.notifier).completeService('1', '1');
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Transaksi INV-1'), findsOneWidget);
    expect(scope.read(auditRevisionProvider), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning to an Owner page explicitly refreshes audit',
      (tester) async {
    var reads = 0;
    intercept((_) {
      reads++;
      return {'data': []};
    });
    final scope = container();
    addTearDown(scope.dispose);
    await scope.read(sessionProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(
          navigatorObservers: [pageRefreshObserver],
          home: ActivePageRefresh(
              path: '/dashboard',
              child: Builder(
                builder: (context) => Scaffold(
                    body: Column(children: [
                  CashierActivityCard(onOpen: () {}),
                  TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const Scaffold(body: Text('Halaman lain')))),
                      child: const Text('Pindah')),
                ])),
              )),
        )));
    await tester.pumpAndSettle();
    final before = reads;
    await tester.tap(find.text('Pindah'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(reads, before + 1);
    expect(tester.takeException(), isNull);
  });
}
