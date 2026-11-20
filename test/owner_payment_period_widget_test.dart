import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_management_system/core/error/exceptions.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/dashboard/data/models/dashboard_owner_model.dart';
import 'package:laundry_management_system/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:laundry_management_system/features/dashboard/presentation/screens/owner_dashboard_screen.dart';
import 'package:laundry_management_system/features/master_data/data/repositories/mock_master_data_repository.dart';
import 'package:laundry_management_system/features/master_data/presentation/providers/master_data_providers.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/mock_transaction_repository.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';

class _Dashboard extends OwnerDashboardNotifier {
  @override
  Future<DashboardOwnerResponse> build() async =>
      DashboardOwnerResponse.fromJson({
        'summary': {'revenue': 999000, 'payments_received': 999000},
        'payment_details': [
          {'invoice': 'INV-WEEK', 'payment_amount': 999000}
        ],
        'chart': [
          {'label': 'Salah periode', 'value': 999000}
        ],
      });
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  final owner = UserEntity(
      id: 'owner-a',
      name: 'Owner fixture',
      username: 'fixture',
      role: UserRole.owner,
      isActive: true,
      createdAt: DateTime(2026));

  testWidgets(
      'failed payment period never displays another period; retry and details are consistent',
      (tester) async {
    var failToday = true;
    final pending = Completer<OwnerFinancialSnapshot>();
    final scope = ProviderContainer(overrides: [
      ownerDashboardProvider.overrideWith(_Dashboard.new),
      transactionRepositoryProvider
          .overrideWithValue(MockTransactionRepository()),
      masterDataRepositoryProvider
          .overrideWithValue(MockMasterDataRepository()),
      ownerFinancialProvider.overrideWith((ref, request) async {
        if (request.period == 'today') {
          if (failToday) throw const ServerException('Fixture gagal');
          return pending.future;
        }
        return OwnerFinancialSnapshot(
            period: request.period,
            paymentsReceived: 888000,
            paymentCount: 0,
            chart: const [],
            paymentDetails: const []);
      }),
    ]);
    addTearDown(scope.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(home: OwnerDashboardScreen(user: owner))));
    await tester.pumpAndSettle();
    expect(find.text('Rp888.000'), findsOneWidget);
    // The first 'Hari ini' is the payment card's filter, not the chart's.
    await tester.tap(find.text('Hari ini').first);
    await tester.pumpAndSettle();
    expect(find.text('Pembayaran gagal dimuat'), findsOneWidget);
    expect(find.text('Rp999.000'), findsNothing);
    expect(find.text('Rp888.000'), findsNothing);
    await tester.tap(find.text('Pembayaran diterima'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    failToday = false;
    await tester.tap(find.text('Coba lagi').first);
    await tester.pump();
    expect(find.text('Rp999.000'), findsNothing);
    expect(find.text('…'), findsOneWidget);
    pending.complete(const OwnerFinancialSnapshot(
        period: 'today',
        paymentsReceived: 30000,
        paymentCount: 1,
        chart: [],
        paymentDetails: [
          {
            'invoice': 'INV-TODAY',
            'customer_name': 'Fixture',
            'payment_amount': 30000
          },
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Rp30.000'), findsOneWidget);
    await tester.tap(find.text('Pembayaran diterima'));
    await tester.pumpAndSettle();
    expect(find.textContaining('INV-TODAY'), findsOneWidget);
    expect(find.textContaining('INV-WEEK'), findsNothing);
    expect(find.text('Rp30.000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a failed revenue chart does not fall back to dashboard or local figures',
      (tester) async {
    final scope = ProviderContainer(overrides: [
      ownerDashboardProvider.overrideWith(_Dashboard.new),
      transactionRepositoryProvider
          .overrideWithValue(MockTransactionRepository()),
      masterDataRepositoryProvider
          .overrideWithValue(MockMasterDataRepository()),
      ownerFinancialProvider.overrideWith((ref, request) async =>
          throw const ServerException('Fixture grafik gagal')),
    ]);
    addTearDown(scope.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp(home: OwnerDashboardScreen(user: owner))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Grafik gagal dimuat'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Grafik gagal dimuat'), findsOneWidget);
    expect(find.text('Salah periode'), findsNothing);
    expect(find.text('Rp999.000'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
