import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/settings/data/datasources/payment_destination_datasource.dart';
import 'package:laundry_management_system/features/settings/domain/entities/payment_destination.dart';
import 'package:laundry_management_system/features/settings/presentation/providers/payment_destination_providers.dart';
import 'package:laundry_management_system/features/settings/presentation/screens/payment_destinations_screen.dart';

const _bank = PaymentDestination(
    id: 1,
    kind: 'transfer',
    name: 'Bank uji',
    bankName: 'Bank Fixture',
    accountHolder: 'Usaha fixture',
    accountNumber: '00123456789');

class _Source extends PaymentDestinationDataSource {
  _Source() : super(Dio());
  int saves = 0;
  @override
  Future<List<PaymentDestination>> list() async => [_bank];
  @override
  Future<void> save(Map<String, dynamic> fields,
      {int? id, Uint8List? image, String? imageName}) async {
    saves++;
  }
}

Future<void> _open(WidgetTester tester, _Source source) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    currentSessionUserIdProvider.overrideWithValue('fixture'),
    currentOperationalOwnerScopeIdProvider.overrideWithValue('owner-fixture'),
    paymentDestinationDataSourceProvider.overrideWithValue(source),
  ], child: const MaterialApp(home: PaymentDestinationsScreen())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty payment destination sheet closes normally',
      (tester) async {
    final source = _Source();
    await _open(tester, source);
    await tester.tap(find.text('Tambah tujuan'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Tambah tujuan pembayaran'), findsNothing);
    expect(find.text('Batalkan perubahan?'), findsNothing);
    expect(source.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dirty payment destination confirms outside tap and Back',
      (tester) async {
    final source = _Source();
    await _open(tester, source);
    await tester.tap(find.text('Tambah tujuan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Draf rekening');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Batalkan perubahan?'), findsOneWidget);
    await tester.tap(find.text('Lanjut mengisi'));
    await tester.pumpAndSettle();
    expect(find.text('Draf rekening'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, batalkan'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(source.saves, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'deactivating a payment destination requires explicit confirmation',
      (tester) async {
    final source = _Source();
    await _open(tester, source);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Nonaktifkan tujuan pembayaran?'), findsOneWidget);
    await tester.tap(find.text('Kembali'));
    await tester.pumpAndSettle();
    expect(source.saves, 0);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, nonaktifkan'));
    await tester.pumpAndSettle();
    expect(source.saves, 1);
    expect(tester.takeException(), isNull);
  });
}
