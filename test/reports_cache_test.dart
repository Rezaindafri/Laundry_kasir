import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_management_system/core/error/exceptions.dart';
import 'package:laundry_management_system/core/utils/business_time.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/reports/data/datasources/report_remote_datasource.dart';
import 'package:laundry_management_system/features/reports/data/models/report_models.dart';
import 'package:laundry_management_system/features/reports/presentation/providers/report_providers.dart';
import 'package:laundry_management_system/features/reports/presentation/screens/reports_screen.dart';

class _EmptySession extends SessionNotifier {
  @override
  Future<UserEntity?> build() async => null;
}

OwnerReportOverview _report(DateTime start, DateTime end, int amount) =>
    OwnerReportOverview.fromJson({
      'period': {
        'start_date': start.toIso8601String(),
        'end_date': end.toIso8601String()
      },
      'summary': {
        'payments_received': amount,
        'order_value': amount + 70000,
        'outstanding_amount': 70000
      },
      'accounts': [
        {
          'id': 'owner-a',
          'name': 'Owner A',
          'is_owner': true,
          'is_active': true
        },
        {'id': 'cashier-a', 'name': 'Kasir A', 'is_active': false},
      ],
    });

class _Remote implements ReportRemoteDataSource {
  int amount = 30000;
  int calls = 0;
  bool failBackground = false;
  bool failForeground = false;
  DateTime? exportedStart;
  String? exportedCashier;
  final held = <String, Completer<OwnerReportOverview>>{};
  final requests = <String>[];
  static String key(DateTime start, DateTime end, String? cashier) =>
      '${start.toIso8601String()}/${end.toIso8601String()}/$cashier';

  @override
  Future<OwnerReportOverview> getOverview(
      {required DateTime startDate,
      required DateTime endDate,
      String? cashierId,
      bool background = false}) async {
    calls++;
    final requestKey = key(startDate, endDate, cashierId);
    requests.add(requestKey);
    if (background && failBackground || !background && failForeground) {
      throw const ServerException('Gagal memuat laporan.');
    }
    if (held[requestKey] case final pending?) return pending.future;
    return _report(startDate, endDate, amount);
  }

  @override
  Future<Uint8List> exportCsv(
      {required DateTime startDate,
      required DateTime endDate,
      String? cashierId}) async {
    exportedStart = startDate;
    exportedCashier = cashierId;
    return Uint8List(0);
  }
}

Future<void> _drain() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProviderContainer _container(_Remote remote) => ProviderContainer(overrides: [
      currentSessionUserIdProvider.overrideWithValue('owner-a'),
      reportRemoteDataSourceProvider.overrideWithValue(remote),
    ]);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test(
      'period/account presets are prefetched, reused, and preserve server totals',
      () async {
    final remote = _Remote();
    final container = _container(remote);
    addTearDown(container.dispose);
    await container.read(reportsOverviewProvider.future);
    await _drain();
    final now = BusinessTime.calendarNow();
    final today = DateTime(now.year, now.month, now.day);
    final week = DateTimeRange(
        start: today.subtract(const Duration(days: 6)), end: today);
    final calls = remote.calls;
    final notifier = container.read(reportsOverviewProvider.notifier);
    final switching = notifier.setRange(week);
    // No AsyncLoading even for one frame on a cache hit.
    expect(container.read(reportsOverviewProvider).isLoading, isFalse);
    await switching;
    await notifier.setCashier('cashier-a');
    await _drain();
    expect(remote.calls, calls);
    final report = container.read(reportsOverviewProvider).requireValue;
    expect(report.paymentsReceived, 30000);
    expect(report.orderValue, 100000);
    expect(report.outstandingAmount, 70000);
    expect(notifier.cashierId, 'cashier-a');
    await notifier.exportCsv();
    expect(remote.exportedStart, week.start);
    expect(remote.exportedCashier, 'cashier-a');
    expect(remote.requests.any((key) => key.contains('owner-b')), isFalse);
  });

  test('late filter response never replaces newer filter', () async {
    final remote = _Remote();
    final container = _container(remote);
    addTearDown(container.dispose);
    await container.read(reportsOverviewProvider.future);
    await _drain();
    final a =
        DateTimeRange(start: DateTime(2025, 1), end: DateTime(2025, 1, 2));
    final b =
        DateTimeRange(start: DateTime(2025, 2), end: DateTime(2025, 2, 2));
    final first = Completer<OwnerReportOverview>();
    final second = Completer<OwnerReportOverview>();
    remote.held[_Remote.key(a.start, a.end, null)] = first;
    remote.held[_Remote.key(b.start, b.end, null)] = second;
    final notifier = container.read(reportsOverviewProvider.notifier);
    final selectingA = notifier.setRange(a);
    expect(container.read(reportsOverviewProvider).isLoading, isTrue);
    final selectingB = notifier.setRange(b);
    second.complete(_report(b.start, b.end, 222));
    await selectingB;
    first.complete(_report(a.start, a.end, 111));
    await selectingA;
    expect(
        container.read(reportsOverviewProvider).requireValue.paymentsReceived,
        222);
    expect(notifier.range, b);
  });

  test(
      'background failure is silent; foreground error can retry and refresh clears cache',
      () async {
    final remote = _Remote()..failBackground = true;
    final container = _container(remote);
    addTearDown(container.dispose);
    await container.read(reportsOverviewProvider.future);
    await _drain();
    expect(container.read(reportsOverviewProvider).hasError, isFalse);
    expect(remote.calls, lessThanOrEqualTo(3));
    final notifier = container.read(reportsOverviewProvider.notifier);
    remote.failForeground = true;
    await notifier.setRange(
        DateTimeRange(start: DateTime(2025), end: DateTime(2025, 1, 2)));
    expect(container.read(reportsOverviewProvider).hasError, isTrue);
    remote.failForeground = false;
    remote.amount = 44000;
    await notifier.refresh();
    expect(
        container.read(reportsOverviewProvider).requireValue.paymentsReceived,
        44000);
  });

  test(
      'session change clears report cache and rejects late old-account response',
      () async {
    final actor = StateProvider<String?>((ref) => 'owner-a');
    final remote = _Remote();
    final container = ProviderContainer(overrides: [
      currentSessionUserIdProvider.overrideWith((ref) => ref.watch(actor)),
      reportRemoteDataSourceProvider.overrideWithValue(remote),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(reportsOverviewProvider, (_, __) {});
    addTearDown(subscription.close);
    await container.read(reportsOverviewProvider.future);
    await _drain();
    final range =
        DateTimeRange(start: DateTime(2025), end: DateTime(2025, 1, 3));
    final pending = Completer<OwnerReportOverview>();
    remote.held[_Remote.key(range.start, range.end, null)] = pending;
    final oldSelection =
        container.read(reportsOverviewProvider.notifier).setRange(range);
    container.read(actor.notifier).state = 'owner-b';
    remote.amount = 88000;
    await container.read(reportsOverviewProvider.future);
    pending.complete(_report(range.start, range.end, 1));
    await oldSelection;
    expect(
        container.read(reportsOverviewProvider).requireValue.paymentsReceived,
        88000);
    expect(container.read(reportsOverviewProvider.notifier).cashierId, isNull);
  });

  testWidgets('report filters remain usable while an uncached selection loads',
      (tester) async {
    final remote = _Remote();
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionProvider.overrideWith(_EmptySession.new),
      currentSessionUserIdProvider.overrideWithValue('owner-a'),
      reportRemoteDataSourceProvider.overrideWithValue(remote),
    ], child: const MaterialApp(home: ReportsScreen())));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(ReportsScreen));
    final container = ProviderScope.containerOf(element);
    final pending = Completer<OwnerReportOverview>();
    final range =
        DateTimeRange(start: DateTime(2025), end: DateTime(2025, 1, 4));
    remote.held[_Remote.key(range.start, range.end, null)] = pending;
    final switching =
        container.read(reportsOverviewProvider.notifier).setRange(range);
    await tester.pump();
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Me (Owner)'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Rp30.000'), findsNothing);
    await tester.tap(find.text('Hari ini'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    pending.complete(_report(range.start, range.end, 1));
    await switching;
    await tester.pumpAndSettle();
    expect(
        container.read(reportsOverviewProvider).requireValue.paymentsReceived,
        30000);
    expect(tester.takeException(), isNull);
  });

  test('malformed API response is an error, never a fake zero report',
      () async {
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.resolve(Response(
            requestOptions: options,
            data: '<html>error</html>',
            statusCode: 200));
      }));
    await expectLater(
        ReportRemoteDataSourceImpl(dio)
            .getOverview(startDate: DateTime(2026), endDate: DateTime(2026)),
        throwsA(isA<ServerException>()));
    dio.close();
  });

  test('cache expires after two minutes or a WIB date change', () async {
    var now = DateTime(2026, 10, 22, 23, 59);
    final remote = _Remote();
    final container = ProviderContainer(overrides: [
      currentSessionUserIdProvider.overrideWithValue('owner-a'),
      reportRemoteDataSourceProvider.overrideWithValue(remote),
      reportClockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(container.dispose);
    await container.read(reportsOverviewProvider.future);
    await _drain();
    final notifier = container.read(reportsOverviewProvider.notifier);
    remote.amount = 40000;
    now = DateTime(2026, 10, 23);
    await notifier.setCashier(null);
    expect(
        container.read(reportsOverviewProvider).requireValue.paymentsReceived,
        40000);
    expect(container.read(reportsOverviewProvider).requireValue.startDate,
        DateTime(2026, 10, 23));
    await _drain();
    remote.amount = 50000;
    now = now.add(const Duration(minutes: 3));
    await notifier.setCashier(null);
    expect(
        container.read(reportsOverviewProvider).requireValue.paymentsReceived,
        50000);
  });

  test('a slow initial load cannot overwrite a later selected report',
      () async {
    final remote = _Remote();
    final now = BusinessTime.calendarNow();
    final today = DateTime(now.year, now.month, now.day);
    final initial = Completer<OwnerReportOverview>();
    remote.held[_Remote.key(today, today, null)] = initial;
    final container = _container(remote);
    addTearDown(container.dispose);
    final loading = container.read(reportsOverviewProvider.future);
    final selected =
        DateTimeRange(start: DateTime(2025), end: DateTime(2025, 1, 4));
    await container.read(reportsOverviewProvider.notifier).setRange(selected);
    initial.complete(_report(today, today, 1));
    await loading;
    await _drain();
    expect(
        container.read(reportsOverviewProvider).requireValue.paymentsReceived,
        30000);
    expect(container.read(reportsOverviewProvider).requireValue.startDate,
        selected.start);
  });

  test(
      'real datasource sends date/account filters without changing Laravel contract',
      () async {
    RequestOptions? request;
    final dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        request = options;
        handler
            .resolve(Response(requestOptions: options, statusCode: 200, data: {
          'data': {
            'period': {'start_date': '2026-10-01', 'end_date': '2026-10-22'},
            'summary': {
              'payments_received': 30000,
              'order_value': 100000,
              'outstanding_amount': 70000
            },
          },
        }));
      }));
    final report = await ReportRemoteDataSourceImpl(dio).getOverview(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 22),
        cashierId: 'owner-a',
        background: true);
    expect(request?.path, '/reports/overview');
    expect(request?.queryParameters, {
      'start_date': '2026-10-01',
      'end_date': '2026-10-22',
      'cashier_id': 'owner-a'
    });
    expect(request?.extra['silentFailure'], isTrue);
    expect(report.paymentsReceived, 30000);
    expect(report.outstandingAmount, 70000);
    dio.close();
  });
}
