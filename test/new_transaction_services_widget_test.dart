import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_management_system/core/error/failures.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/master_data/data/repositories/mock_master_data_repository.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/customer_entity.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/laundry_service_entity.dart';
import 'package:laundry_management_system/features/master_data/presentation/providers/master_data_providers.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/mock_transaction_repository.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/transactions_screen.dart';

const _customer = CustomerEntity(id: 'fixture-customer', name: 'Pelanggan uji');
const _services = [
  LaundryServiceEntity(
      id: '1', name: 'Cuci cepat', price: 10000, unit: 'kg', estimatedHours: 2),
  LaundryServiceEntity(
      id: '2', name: 'Barang', price: 5000, unit: 'item', estimatedHours: 0),
  LaundryServiceEntity(
      id: '3', name: 'Setrika', price: 6000, unit: 'kg', estimatedHours: 4),
];

class _MasterFixture extends MockMasterDataRepository {
  @override
  Future<Result<List<LaundryServiceEntity>>> getServices() async =>
      const Success(_services);
  @override
  Future<Result<List<CustomerEntity>>> getCustomers() async =>
      const Success([_customer]);
}

// Capture what the real form submits without using a network/database or
// navigating to detail features that access hardware/settings.
class _OrderFixture extends MockTransactionRepository {
  TransactionEntity? submitted;
  int calls = 0;
  @override
  Future<Result<TransactionEntity>> create(
      TransactionEntity transaction) async {
    submitted = transaction;
    calls++;
    return const Error(
        ServerFailure('Fixture: stop after capturing submission.'));
  }
}

Finder _picker(int index) =>
    find.byKey(ValueKey('transaction-service-picker-$index'));
Finder _quantity(int index) =>
    find.byKey(ValueKey('transaction-service-quantity-$index'));
final _add = find.byKey(const ValueKey('transaction-add-service'));

Future<void> _open(WidgetTester tester, _OrderFixture repository,
    {Size size = const Size(390, 1200)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        currentSessionUserIdProvider.overrideWithValue('fixture-session'),
        masterDataRepositoryProvider.overrideWithValue(_MasterFixture()),
        transactionRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
          home: NewTransactionScreen(initialCustomer: _customer))));
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 180,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, int index, String name) async {
  await _reveal(tester, _picker(index));
  await tester.tap(_picker(index));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, name));
  await tester.pumpAndSettle();
}

Future<void> _addLine(WidgetTester tester) async {
  await _reveal(tester, _add);
  await tester.tap(_add);
  await tester.pumpAndSettle();
}

Future<void> _choosePayment(WidgetTester tester, String label) async {
  final status = find.byType(DropdownButtonFormField<PaymentStatus>);
  await _reveal(tester, status);
  await tester.tap(status);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

final _paymentAmount =
    find.widgetWithText(TextFormField, 'Pembayaran masuk (Rp)');

String _amountText(WidgetTester tester) =>
    tester.widget<TextFormField>(_paymentAmount).controller!.text;

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
      'one service section starts with a card; add inserts the same card before Express',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository);
    expect(find.text('Layanan'), findsOneWidget);
    expect(find.text('Layanan 1'), findsOneWidget);
    expect(_picker(0), findsOneWidget);
    expect(find.byTooltip('Hapus layanan dari bon'), findsNothing);
    expect(find.text('Tambah layanan ke bon ini'), findsNothing);
    await _addLine(tester);
    expect(find.text('Layanan 2'), findsOneWidget);
    expect(_picker(1), findsOneWidget);
    expect(find.byType(TextField),
        findsNWidgets(3)); // quantities + notes, not SearchDelegate
    expect(tester.getTopLeft(_picker(0)).dy,
        lessThan(tester.getTopLeft(_picker(1)).dy));
    expect(tester.getBottomLeft(_picker(1)).dy,
        lessThan(tester.getTopLeft(_add).dy));
    expect(tester.getBottomLeft(_add).dy,
        lessThan(tester.getTopLeft(find.byType(SwitchListTile)).dy));
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih layanan untuk baris ini.'), findsNWidgets(2));
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unified cards submit quantities, Express, DP and zero estimate without changing totals',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository);
    await _select(tester, 0, 'Cuci cepat');
    await tester.enterText(_quantity(0), '2,5');
    await _addLine(tester);
    await _select(tester, 1, 'Barang');
    // Barang now sorts before Cuci; quantities stay with their own drafts.
    expect(tester.widget<TextFormField>(_quantity(1)).controller!.text, '2,5');
    await tester.enterText(_quantity(0), '2');
    expect(find.text('Langsung siap diambil · tanpa estimasi'), findsOneWidget);
    await _reveal(tester, find.byType(SwitchListTile));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final paymentStatus = find.byType(DropdownButtonFormField<PaymentStatus>);
    await _reveal(tester, paymentStatus);
    await tester.tap(paymentStatus);
    await tester.pumpAndSettle();
    await tester.tap(find.text('DP').last);
    await tester.pumpAndSettle();
    final deposit = find.widgetWithText(TextFormField, 'Pembayaran masuk (Rp)');
    await _reveal(tester, deposit);
    expect(tester.widget<TextFormField>(deposit).controller!.text, '43750');
    await tester.enterText(deposit, '10000');
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    final submitted = repository.submitted!;
    expect(repository.calls, 1);
    expect(submitted.details.map((line) => line.serviceId), ['2', '1']);
    expect(submitted.details.map((line) => line.quantity), [2.0, 2.5]);
    expect(submitted.details.map((line) => line.subtotal), [12500, 31250]);
    expect(submitted.expressFee, 8750);
    expect(submitted.total, 43750);
    expect(submitted.paidAmount, 10000);
    expect(submitted.paymentStatus, PaymentStatus.downPayment);
    expect(submitted.details.last.estimatedFinishAt,
        submitted.createdAt.add(const Duration(hours: 2)));
    expect(submitted.details.first.estimatedFinishAt, isNull);
    expect(
        submitted.estimatedFinishAt, submitted.details.last.estimatedFinishAt);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'removing the focused first card preserves other cards and never removes the last card',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository);
    await _select(tester, 0, 'Cuci cepat');
    await tester.enterText(_quantity(0), '3');
    await _addLine(tester);
    await _select(tester, 1, 'Setrika');
    await tester.enterText(_quantity(1), '4');
    final firstCard =
        find.ancestor(of: _picker(0), matching: find.byType(Card));
    await _reveal(tester, firstCard);
    await tester.tap(_quantity(0));
    await tester.pump();
    await tester.tap(find.descendant(
        of: firstCard, matching: find.byTooltip('Hapus layanan dari bon')));
    await tester.pumpAndSettle();
    expect(find.text('Hapus layanan dari bon?'), findsOneWidget);
    await tester.tap(find.text('Hapus layanan'));
    await tester.pumpAndSettle();
    expect(find.text('Layanan 2'), findsNothing);
    expect(find.text('Setrika'), findsOneWidget);
    expect(tester.widget<TextFormField>(_quantity(0)).controller!.text, '4');
    expect(find.byTooltip('Hapus layanan dari bon'), findsNothing);
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(repository.submitted!.details.single.serviceId, '3');
    expect(repository.submitted!.details.single.quantity, 4);
    expect(repository.submitted!.total, 24000);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'small-screen form rejects a missing quantity even when its card has scrolled offscreen',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository, size: const Size(320, 640));
    await _select(tester, 0, 'Cuci cepat');
    await _addLine(tester);
    await _select(tester, 1, 'Barang');
    await _reveal(tester, find.byType(SwitchListTile));
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new transaction autofills full bill and sends a paid order',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository);
    await _select(tester, 0, 'Cuci cepat');
    await tester.enterText(_quantity(0), '2');
    await _choosePayment(tester, 'Lunas');
    await _reveal(tester, _paymentAmount);
    expect(_amountText(tester), '20000');
    await tester.tap(_paymentAmount);
    await tester.pump();
    expect(tester.widget<TextFormField>(_paymentAmount).controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5));
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(repository.submitted!.paidAmount, 20000);
    expect(repository.submitted!.paymentStatus, PaymentStatus.paid);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'automatic payment follows quantity, Express, added and removed services',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository);
    await _select(tester, 0, 'Cuci cepat');
    await tester.enterText(_quantity(0), '2');
    await _choosePayment(tester, 'Lunas');
    await _reveal(tester, _quantity(0));
    await tester.enterText(_quantity(0), '3');
    await _reveal(tester, _paymentAmount);
    expect(_amountText(tester), '30000');
    await _reveal(tester, find.byType(SwitchListTile));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await _reveal(tester, _paymentAmount);
    expect(_amountText(tester), '37500');
    await _addLine(tester);
    await _select(tester, 1, 'Barang');
    await _reveal(tester, _paymentAmount);
    expect(_amountText(tester), '43750');
    final firstCard =
        find.ancestor(of: _picker(0), matching: find.byType(Card));
    await _reveal(tester, firstCard);
    await tester.tap(find.descendant(
        of: firstCard, matching: find.byTooltip('Hapus layanan dari bon')));
    await tester.pumpAndSettle();
    expect(find.text('Hapus layanan dari bon?'), findsOneWidget);
    await tester.tap(find.text('Hapus layanan'));
    await tester.pumpAndSettle();
    await _reveal(tester, _paymentAmount);
    expect(_amountText(tester), '37500');
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(repository.submitted!.total, 37500);
    expect(repository.submitted!.paidAmount, 37500);
    expect(repository.submitted!.paymentStatus, PaymentStatus.paid);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'manual initial payment remains intact after bill changes and sends DP',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository);
    await _select(tester, 0, 'Cuci cepat');
    await tester.enterText(_quantity(0), '2');
    await _choosePayment(tester, 'Lunas');
    await _reveal(tester, _paymentAmount);
    await tester.enterText(_paymentAmount, '5000');
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButtonFormField<PaymentStatus>>(
                find.byType(DropdownButtonFormField<PaymentStatus>))
            .initialValue,
        PaymentStatus.downPayment);
    await _reveal(tester, _quantity(0));
    await tester.enterText(_quantity(0), '3');
    await _reveal(tester, _paymentAmount);
    expect(_amountText(tester), '5000');
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(repository.submitted!.total, 30000);
    expect(repository.submitted!.paidAmount, 5000);
    expect(repository.submitted!.paymentStatus, PaymentStatus.downPayment);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cleared or excessive initial payment is rejected; unpaid stays unpaid',
      (tester) async {
    final repository = _OrderFixture();
    await _open(tester, repository, size: const Size(320, 640));
    await _select(tester, 0, 'Cuci cepat');
    await tester.enterText(_quantity(0), '2');
    await _choosePayment(tester, 'DP');
    await _reveal(tester, _paymentAmount);
    expect(_amountText(tester), '20000');
    for (final invalid in ['', '0', '20001']) {
      await tester.enterText(_paymentAmount, invalid);
      await tester.tap(find.text('Simpan Transaksi'));
      await tester.pumpAndSettle();
      expect(repository.calls, 0);
    }
    await _choosePayment(tester, 'Belum Bayar');
    expect(_paymentAmount, findsNothing);
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(repository.submitted!.paidAmount, 0);
    expect(repository.submitted!.paymentStatus, PaymentStatus.unpaid);
    expect(tester.takeException(), isNull);
  });
}
