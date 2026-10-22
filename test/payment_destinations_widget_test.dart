import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/core/widgets/safe_modal_sheet.dart';
import 'package:laundry_management_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/features/settings/data/datasources/payment_destination_datasource.dart';
import 'package:laundry_management_system/features/settings/domain/entities/payment_destination.dart';
import 'package:laundry_management_system/features/settings/domain/entities/laundry_settings.dart';
import 'package:laundry_management_system/features/settings/presentation/providers/settings_providers.dart';
import 'package:laundry_management_system/features/settings/presentation/providers/payment_destination_providers.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/mock_transaction_repository.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/payment_entry_sheet.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/payment_destination_picker.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/transaction_evidence_section.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/transaction_proof_dialog.dart';
import 'package:laundry_management_system/shared/enums/user_role.dart';

const _bankA = PaymentDestination(
    id: 1,
    kind: 'transfer',
    name: 'Utama',
    bankName: 'Bank A',
    accountHolder: 'Usaha A',
    accountNumber: '00123456789');
const _bankB = PaymentDestination(
    id: 2,
    kind: 'transfer',
    name: 'Cadangan',
    bankName: 'Bank B',
    accountHolder: 'Usaha B',
    accountNumber: '00987654321');
const _qris = PaymentDestination(
    id: 3, kind: 'qris', name: 'QRIS usaha', hasQrisImage: true);

class _Source extends PaymentDestinationDataSource {
  _Source(this.items, [this.png]) : super(Dio());
  List<PaymentDestination> items;
  final Uint8List? png;
  int reads = 0, images = 0;
  bool fail = false;
  @override
  Future<List<PaymentDestination>> list() async {
    reads++;
    if (fail) throw StateError('fixture');
    return items;
  }

  @override
  Future<Uint8List> image(int id) async {
    images++;
    return png!;
  }
}

class _Session extends SessionNotifier {
  @override
  Future<UserEntity?> build() async => UserEntity(
      id: 'owner-fixture',
      name: 'Owner fixture',
      username: 'fixture',
      role: UserRole.owner,
      isActive: true,
      createdAt: DateTime(2026));
}

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder)
      .drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..color = Colors.blue);
  final picture = recorder.endRecording();
  final image = await picture.toImage(2, 2);
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
  image.dispose();
  picture.dispose();
  return bytes;
}

Future<void> _sheet(WidgetTester tester, _Source source, PaymentMethod method,
    ValueChanged<PaymentEntry?> onResult,
    {PaymentEntry? previous}) async {
  await tester.pumpWidget(ProviderScope(
      overrides: [
        currentSessionUserIdProvider.overrideWithValue('fixture'),
        currentOperationalOwnerScopeIdProvider
            .overrideWithValue('owner-fixture'),
        paymentDestinationDataSourceProvider.overrideWithValue(source),
      ],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async => onResult(
                          await showSafeModalBottomSheet<PaymentEntry>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => PaymentEntrySheet(
                                  minimum: 1,
                                  maximum: 10000,
                                  method: method,
                                  previous: previous))),
                      child: const Text('Buka')))))));
  await tester.tap(find.text('Buka'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Catat Pembayaran'));
  await tester.tap(find.text('Catat Pembayaran'));
  await tester.pumpAndSettle();
}

TransactionEntity _order({bool photo = false, bool records = false}) =>
    TransactionEntity(
        id: '1',
        invoice: 'INV-FIXTURE',
        customerId: '1',
        customerName: 'Pelanggan',
        customerPhone: '',
        serviceName: 'Goods',
        quantity: 1,
        quantityUnit: 'item',
        unitPrice: 10000,
        expressFee: 0,
        total: 10000,
        paidAmount: 10000,
        paymentMethod: PaymentMethod.transfer,
        paymentStatus: PaymentStatus.paid,
        laundryStatus: LaundryStatus.collected,
        createdAt: DateTime.utc(2026, 10, 11),
        estimatedFinishAt: DateTime.utc(2026, 10, 11),
        hasProofImage: photo,
        details: [
          TransactionLineEntity(
              id: '11',
              serviceId: '1',
              name: 'Goods',
              quantity: 1,
              unit: 'item',
              unitPrice: 10000,
              subtotal: 10000,
              status: LaundryStatus.collected,
              hasProofImage: photo,
              collectedAt: DateTime.utc(2026, 10, 11, 2))
        ],
        payments: records
            ? [
                TransactionPaymentRecord(
                    amount: 10000,
                    method: 'transfer',
                    paidAt: DateTime.utc(2026, 10, 11, 1),
                    destinationLabel: 'Utama - Bank A',
                    recorderName: 'Kasir fixture')
              ]
            : []);

class _Orders extends MockTransactionRepository {
  _Orders(this.order);
  final TransactionEntity order;
  @override
  Future<Success<TransactionEntity>> getById(String id) async => Success(order);
}

class _SlowSettings extends LaundrySettingsNotifier {
  _SlowSettings(this.pending);
  final Completer<LaundrySettings> pending;
  @override
  Future<LaundrySettings> build() => pending.future;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets(
      'first receipt action waits for actual business and saved printer settings',
      (tester) async {
    final settings = Completer<LaundrySettings>();
    final order = _order();
    await tester.pumpWidget(ProviderScope(overrides: [
      sessionProvider.overrideWith(_Session.new),
      transactionRepositoryProvider.overrideWithValue(_Orders(order)),
      laundrySettingsProvider.overrideWith(() => _SlowSettings(settings)),
    ], child: MaterialApp(home: TransactionDetailScreen(transaction: order))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cetak Bon'));
    await tester.pump();
    expect(find.text('Memproses...'), findsOneWidget);
    expect(find.text('Print bon'), findsNothing);
    settings.complete(const LaundrySettings(
        businessName: 'Usaha sebenarnya',
        phone: '',
        address: '',
        paperSize: '58 mm',
        defaultPrinter: 'AA:BB:CC:DD:EE:FF',
        defaultPrinterName: 'Printer tersimpan'));
    await tester.pumpAndSettle();
    expect(find.text('Printer tersimpan'), findsOneWidget);
    final printChoice = tester.widget<ListTile>(find.ancestor(
        of: find.text('Print bon'), matching: find.byType(ListTile)));
    expect(printChoice.enabled, isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash has no destination lookup or extra account controls',
      (tester) async {
    final source = _Source([_bankA]);
    PaymentEntry? entry;
    await _sheet(tester, source, PaymentMethod.cash, (value) => entry = value);
    expect(source.reads, 0);
    expect(find.text('Tujuan pembayaran'), findsNothing);
    await _submit(tester);
    expect(entry!.method, PaymentMethod.cash);
    expect(entry!.destinationId, isNull);
    expect(entry!.amount, 10000);
  });

  testWidgets('transfer shows account and supports more than one bank',
      (tester) async {
    final source = _Source([_bankA, _bankB]);
    PaymentEntry? entry;
    await _sheet(
        tester, source, PaymentMethod.transfer, (value) => entry = value);
    expect(find.text('00123456789'), findsOneWidget);
    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadangan · Bank B').last);
    await tester.pumpAndSettle();
    expect(find.text('00987654321'), findsOneWidget);
    expect(find.text('Atas nama Usaha B'), findsOneWidget);
    await _submit(tester);
    expect(entry!.destinationId, 2);
    expect(source.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('qris renders authorized image and records destination',
      (tester) async {
    final source = _Source([_qris], await tester.runAsync(_png));
    PaymentEntry? entry;
    await _sheet(tester, source, PaymentMethod.qris, (value) => entry = value);
    expect(find.byType(Image), findsOneWidget);
    expect(source.images, 1);
    await _submit(tester);
    expect(entry!.destinationId, 3);
    expect(entry!.method, PaymentMethod.qris);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed destination lookup blocks submit until recovered',
      (tester) async {
    final source = _Source([_bankA])..fail = true;
    PaymentEntry? entry;
    await _sheet(
        tester, source, PaymentMethod.transfer, (value) => entry = value);
    await _submit(tester);
    expect(entry, isNull);
    expect(find.byType(PaymentEntrySheet), findsOneWidget);
    source.fail = false;
    await tester.ensureVisible(find.text('Coba lagi'));
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    await _submit(tester);
    expect(entry!.destinationId, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'retry retains destination and UUID; unknown account never auto-switches',
      (tester) async {
    const previous = PaymentEntry(
        amount: 5000,
        method: PaymentMethod.transfer,
        destinationId: 2,
        requestId: 'dc8a0e58-02fd-4e94-abf8-a749ef2a82bb');
    final source = _Source([_bankA, _bankB]);
    PaymentEntry? entry;
    await _sheet(
        tester, source, PaymentMethod.transfer, (value) => entry = value,
        previous: previous);
    expect(find.text('00987654321'), findsOneWidget);
    await _submit(tester);
    expect(entry!.requestId, previous.requestId);
    expect(entry!.destinationId, 2);
    for (final available in <List<PaymentDestination>>[
      [_bankA],
      []
    ]) {
      await _sheet(tester, _Source(available), PaymentMethod.transfer,
          (value) => entry = value,
          previous: previous);
      entry = null;
      expect(find.textContaining('Tujuan sebelumnya tidak tersedia.'),
          findsOneWidget);
      expect(find.byType(PaymentDestinationInfo), findsNothing);
      await _submit(tester);
      expect(entry, isNull);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    }
  });

  for (final photo in [false, true]) {
    testWidgets(
        'detail displays payment destination and ${photo ? "pickup photo" : "optional evidence note"}',
        (tester) async {
      final png = (await tester.runAsync(_png))!;
      final order = _order(photo: photo, records: true);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_Session.new),
            transactionRepositoryProvider.overrideWithValue(_Orders(order)),
            transactionLineProofProvider.overrideWith((ref, key) async => png),
          ],
          child:
              MaterialApp(home: TransactionDetailScreen(transaction: order))));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byType(TransactionEvidenceSection), 250,
          scrollable: find.byType(Scrollable).first);
      if (photo) {
        expect(find.byType(Image), findsOneWidget);
        await tester.ensureVisible(find.textContaining('Bukti Goods'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Bukti Goods'));
        await tester.pumpAndSettle();
        expect(find.byType(TransactionProofDialog), findsOneWidget);
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();
      } else {
        expect(find.textContaining('Foto opsional, belum tersedia'),
            findsOneWidget);
      }
      await tester.scrollUntilVisible(find.text('Utama - Bank A'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Dicatat oleh Kasir fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
