import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_management_system/features/settings/presentation/providers/payment_destination_providers.dart';
import 'package:laundry_management_system/core/widgets/safe_modal_sheet.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/payment_amount_field.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/payment_entry_sheet.dart';

final _amount = find.widgetWithText(TextFormField, 'Pembayaran masuk (Rp)');
final _amountInput =
    find.descendant(of: _amount, matching: find.byType(TextField));

Future<void> _openSheet(WidgetTester tester,
    {required int minimum,
    required int maximum,
    bool collection = false,
    PaymentEntry? previous,
    required ValueChanged<PaymentEntry?> onResult}) async {
  await tester.pumpWidget(ProviderScope(
      overrides: [
        paymentDestinationsProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        onResult(await showSafeModalBottomSheet<PaymentEntry>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => PaymentEntrySheet(
                                minimum: minimum,
                                maximum: maximum,
                                method: PaymentMethod.cash,
                                forCollection: collection,
                                previous: previous)));
                      },
                      child: const Text('Buka')))))));
  await tester.tap(find.text('Buka'));
  await tester.pumpAndSettle();
}

void main() {
  test('automatic bill follows changes; manual amount and clearing stay intact',
      () {
    final controller = PaymentAmountController(defaultAmount: 10000);
    addTearDown(controller.dispose);
    expect(controller.text, '10000');
    controller.updateDefaultAmount(25000);
    expect(controller.text, '25000');
    controller.text = '5000';
    controller.markEdited();
    controller.updateDefaultAmount(30000);
    expect(controller.text, '5000');
    controller.clear();
    controller.updateDefaultAmount(40000);
    expect(controller.text, isEmpty);
    controller.resetToDefault(40000);
    expect(controller.text, '40000');
    expect(controller.isAutomatic, isTrue);
  });

  test('a failed manual payment is not replaced by a new default bill', () {
    final controller =
        PaymentAmountController(defaultAmount: 60000, initialText: '12500');
    addTearDown(controller.dispose);
    controller.updateDefaultAmount(50000);
    expect(controller.text, '12500');
    expect(controller.isAutomatic, isFalse);
  });

  testWidgets('first typing replaces autofill; later typing edits normally',
      (tester) async {
    final controller = PaymentAmountController(defaultAmount: 60000);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      PaymentAmountField(controller: controller, validator: (_) => null),
      const TextField(decoration: InputDecoration(labelText: 'Catatan')),
    ]))));
    await tester.tap(_amount);
    await tester.pump();
    expect(controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5));
    // Emulate an IME keystroke using the current selection, not enterText
    // (which replaces the entire value regardless of the actual selection).
    final firstKey = controller.value.replaced(controller.selection, '2');
    tester.testTextInput.updateEditingValue(firstKey.copyWith(
        selection: TextSelection.collapsed(offset: firstKey.text.length)));
    await tester.pump();
    expect(controller.text, '2');
    final nextKey = controller.value.replaced(controller.selection, '5');
    tester.testTextInput.updateEditingValue(nextKey.copyWith(
        selection: TextSelection.collapsed(offset: nextKey.text.length)));
    await tester.pump();
    expect(controller.text, '25');
    expect(controller.isAutomatic, isFalse);
    expect(tester.widget<TextField>(_amountInput).selectAllOnFocus, isFalse);
    await tester.tap(find.widgetWithText(TextField, 'Catatan'));
    await tester.pump();
    await tester.tap(_amount);
    await tester.pump();
    expect(controller.selection.isCollapsed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      name: 'Bayar Saja',
      min: 1,
      max: 60000,
      collection: false,
      expected: 60000
    ),
    (
      name: 'partial pickup',
      min: 10000,
      max: 60000,
      collection: true,
      expected: 10000
    ),
    (
      name: 'final pickup',
      min: 60000,
      max: 60000,
      collection: true,
      expected: 60000
    ),
    (name: 'paid pickup', min: 0, max: 0, collection: true, expected: 0),
  ]) {
    testWidgets('${scenario.name} autofills the relevant bill and submits it',
        (tester) async {
      PaymentEntry? entry;
      await _openSheet(tester,
          minimum: scenario.min,
          maximum: scenario.max,
          collection: scenario.collection,
          onResult: (value) => entry = value);
      final field = tester.widget<TextFormField>(_amount);
      expect(field.controller!.text, scenario.expected.toString());
      expect(
          tester.widget<TextField>(_amountInput).readOnly, scenario.max == 0);
      await tester.tap(find.text(
          scenario.collection ? 'Konfirmasi Pengambilan' : 'Catat Pembayaran'));
      await tester.pumpAndSettle();
      expect(entry!.amount, scenario.expected);
      expect(entry!.requestId, isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('manual payments outside pickup bounds cannot submit',
      (tester) async {
    PaymentEntry? entry;
    await _openSheet(tester,
        minimum: 10000,
        maximum: 60000,
        collection: true,
        onResult: (value) => entry = value);
    for (final invalid in ['', '0', '9999', '60001']) {
      await tester.enterText(_amount, invalid);
      await tester.tap(find.text('Konfirmasi Pengambilan'));
      await tester.pumpAndSettle();
      expect(entry, isNull);
      expect(find.byType(PaymentEntrySheet), findsOneWidget);
      expect(find.text('Masukkan nominal 10000–60000.'), findsOneWidget);
    }
    await tester.enterText(_amount, '15000');
    await tester.tap(find.text('Konfirmasi Pengambilan'));
    await tester.pumpAndSettle();
    expect(entry!.amount, 15000);
    expect(tester.takeException(), isNull);
  });

  for (final changed in [false, true]) {
    testWidgets(
        'retry preserves amount, note and request ID unless edited: $changed',
        (tester) async {
      const previous = PaymentEntry(
          amount: 12500,
          method: PaymentMethod.qris,
          requestId: 'dc8a0e58-02fd-4e94-abf8-a749ef2a82bb',
          note: 'DP sebelumnya');
      PaymentEntry? entry;
      await _openSheet(tester,
          minimum: 1,
          maximum: 60000,
          previous: previous,
          onResult: (value) => entry = value);
      expect(tester.widget<TextFormField>(_amount).controller!.text, '12500');
      if (changed) await tester.enterText(_amount, '15000');
      await tester.tap(find.text('Catat Pembayaran'));
      await tester.pumpAndSettle();
      expect(entry!.amount, changed ? 15000 : 12500);
      expect(entry!.method, PaymentMethod.qris);
      expect(entry!.note, 'DP sebelumnya');
      expect(entry!.requestId,
          changed ? isNot(previous.requestId) : previous.requestId);
      expect(tester.takeException(), isNull);
    });
  }
}
