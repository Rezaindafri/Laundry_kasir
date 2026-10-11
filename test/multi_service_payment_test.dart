import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_management_system/features/master_data/data/models/service_model.dart';
import 'package:laundry_management_system/features/master_data/domain/entities/laundry_service_entity.dart';
import 'package:laundry_management_system/features/printing/data/services/thermal_receipt_service_native.dart';
import 'package:laundry_management_system/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:laundry_management_system/features/transactions/data/models/transaction_model.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:laundry_management_system/features/transactions/data/repositories/mock_transaction_repository.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/features/auth/presentation/providers/auth_providers.dart';
import 'package:laundry_management_system/core/utils/result.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';
import 'package:laundry_management_system/features/transactions/presentation/screens/transactions_screen.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/payment_entry_sheet.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/transaction_service_lines.dart';

Map<String, dynamic> _payload() => {
      'id': 1,
      'invoice_number': 'INV-MULTI-1',
      'customer_id': 1,
      'customer': {'name': 'Fixture customer'},
      'total_price': 80000,
      'paid_amount': 20000,
      'payment_status': 'downPayment',
      'created_at': '2026-10-10T07:00:00Z',
      'estimated_finish_at': '2026-10-10T11:00:00Z',
      'laundry_status': 'received',
      'transaction_details': [
        {
          'id': 11,
          'service_id': 1,
          'service_name': 'Cuci cepat',
          'service_unit': 'kg',
          'qty': 3,
          'price': 10000,
          'subtotal': 30000,
          'estimated_finish_at': '2026-10-10T09:00:00Z',
          'laundry_status': 'completed'
        },
        {
          'id': 12,
          'service_id': 2,
          'service_name': 'Setrika',
          'service_unit': 'item',
          'qty': 5,
          'price': 10000,
          'subtotal': 50000,
          'estimated_finish_at': '2026-10-10T11:00:00Z',
          'laundry_status': 'received'
        },
      ],
    };

class _FixtureAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'data': _payload()}), 200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

class _CollectionFixture extends MockTransactionRepository {
  List<String>? pickedIds;
  int? receivedAmount;
  String? receivedNote;

  @override
  Future<Result<List<TransactionEntity>>> getTransactions() async =>
      Success([TransactionModel.fromJson(_payload()).toEntity()]);

  @override
  Future<Result<TransactionEntity>> pay(
      {required TransactionEntity transaction,
      required int amount,
      required PaymentMethod method,
      String? note,
      required String requestId}) async {
    receivedAmount = amount;
    receivedNote = note;
    return Success(
        transaction.copyWith(paidAmount: transaction.paidAmount + amount));
  }

  @override
  Future<Result<TransactionEntity>> collect(
      {required TransactionEntity transaction,
      required bool settlePayment,
      Uint8List? proofImage,
      List<String>? detailIds,
      int? paymentAmount,
      String? paymentNote}) async {
    pickedIds = detailIds;
    receivedAmount = paymentAmount;
    receivedNote = paymentNote;
    final json = _payload();
    (json['transaction_details'] as List).first['laundry_status'] = 'collected';
    json['paid_amount'] = 30000;
    return Success(TransactionModel.fromJson(json).toEntity());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID'));

  for (final collection in [false, true]) {
    testWidgets(
        collection
            ? 'collection screen sends ONLY selected services and new payment'
            : 'Bayar Saja screen records a partial amount without handover',
        (tester) async {
      final repository = _CollectionFixture();
      await tester.pumpWidget(ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(repository),
            currentSessionUserIdProvider.overrideWithValue('fixture'),
          ],
          child: MaterialApp(
              home: CollectionSettlementScreen(
                  transaction:
                      TransactionModel.fromJson(_payload()).toEntity()))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(collection ? 'Bayar & Ambil' : 'Bayar Saja'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          collection ? '10000' : '60000');
      await tester.enterText(find.byType(TextFormField).first, '10000');
      await tester.enterText(
          find.byType(TextFormField).last, 'Fixture catatan');
      await tester.tap(find
          .text(collection ? 'Konfirmasi Pengambilan' : 'Catat Pembayaran'));
      await tester.pumpAndSettle();
      expect(repository.receivedAmount, 10000);
      expect(repository.receivedNote, 'Fixture catatan');
      expect(repository.pickedIds, collection ? ['11'] : null);
      expect(find.byType(CollectionSettlementScreen), findsNothing);
      expect(find.text('Pengambilan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('all service lines and backend readiness survive entity/copy/JSON', () {
    final entity = TransactionModel.fromJson(_payload()).toEntity();
    expect(entity.details.length, 2);
    expect(entity.details.map((line) => line.name), ['Cuci cepat', 'Setrika']);
    expect(entity.hasReadyItems, isTrue);
    expect(entity.isProcessing, isTrue);
    expect(entity.copyWith(paidAmount: 30000).details, entity.details);
    expect(entity.minimumPaymentFor([entity.details.first]), 10000);
    expect(entity.minimumPaymentFor(entity.details), 60000);
    expect(entity.details.first.estimatedFinishAt,
        DateTime.parse('2026-10-10T09:00:00Z'));
  });

  test(
      'no estimate is not fabricated from creation time or current service config',
      () {
    final entity = TransactionModel.fromJson({
      ..._payload(),
      'estimated_finish_at': null,
      'transaction_details': [
        {
          'id': 11,
          'service_id': 1,
          'qty': 1,
          'price': 10000,
          'subtotal': 10000,
          'estimated_finish_at': null,
          'laundry_status': 'completed',
          'service': {'name': 'Barang', 'estimation_hours': 24}
        }
      ],
    }).toEntity();
    expect(entity.hasEstimatedFinish, isFalse);
    expect(entity.details.single.estimatedFinishAt, isNull);
    expect(entity.hasReadyItems, isTrue);
  });

  test('service day duration is sent in actual hours and zero is retained', () {
    const service = LaundryServiceEntity(
        id: '1',
        name: 'Fixture',
        price: 10000,
        unit: 'item',
        estimatedHours: 2,
        estimateUnit: EstimateDurationUnit.days);
    expect(ServiceModel.toRequest(service)['estimation_hours'], 48);
    expect(
        ServiceModel.toRequest(
            service.copyWith(estimatedHours: 0))['estimation_hours'],
        0);
    expect(service.copyWith(estimatedHours: 0).estimatedDurationLabel,
        'Tanpa estimasi');
  });

  test('repository creation sends ALL lines to Laravel, not just the first',
      () async {
    final adapter = _FixtureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
      ..httpClientAdapter = adapter;
    final repository = TransactionRepositoryImpl(
        remoteDataSource: TransactionRemoteDataSourceImpl(dio));
    final result = await repository
        .create(TransactionModel.fromJson(_payload()).toEntity());
    expect(result.isSuccess, isTrue);
    final data = adapter.requests.single.data as Map;
    expect((data['services'] as List).length, 2);
    expect((data['services'] as List)[1]['qty'], 5);
    expect((data['services'] as List)[1]['service_id'], 2);
    dio.close(force: true);
  });

  test('payment sends incremental amount/note/idempotency key, not old total',
      () async {
    final adapter = _FixtureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
      ..httpClientAdapter = adapter;
    final source = TransactionRemoteDataSourceImpl(dio);
    await source.recordPayment(
        id: '1',
        amount: 10000,
        method: 'qris',
        note: 'DP lagi',
        requestId: 'fc7b7934-2e5d-4aa7-b25f-c7243d55e309');
    expect(adapter.requests.single.data, {
      'amount': 10000,
      'payment_method': 'qris',
      'payment_note': 'DP lagi',
      'request_id': 'fc7b7934-2e5d-4aa7-b25f-c7243d55e309',
    });
    dio.close(force: true);
  });

  test('collection sends selected detail IDs, real new amount, and boolean 0',
      () async {
    final adapter = _FixtureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
      ..httpClientAdapter = adapter;
    await TransactionRemoteDataSourceImpl(dio).collectTransaction(
        transaction: TransactionModel.fromJson(_payload()),
        settlePayment: false,
        detailIds: ['11'],
        paymentAmount: 10000,
        paymentNote: 'Ambil satu');
    final fields = Map<String, String>.fromEntries(
        (adapter.requests.single.data as FormData).fields);
    expect(fields['detail_ids[]'], '11');
    expect(fields['settle_payment'], '0');
    expect(fields['payment_amount'], '10000');
    expect(fields['payment_note'], 'Ambil satu');
    dio.close(force: true);
  });

  test('destination ID reaches Laravel for creation, payment and collection',
      () async {
    final adapter = _FixtureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api'))
      ..httpClientAdapter = adapter;
    final source = TransactionRemoteDataSourceImpl(dio);
    final repository = TransactionRepositoryImpl(remoteDataSource: source);
    final order = TransactionModel.fromJson(_payload()).toEntity().copyWith(
        paymentMethod: PaymentMethod.transfer, paymentDestinationId: 42);
    expect((await repository.create(order)).isSuccess, isTrue);
    expect((adapter.requests.last.data as Map)['payment_destination_id'], 42);
    expect(
        (await repository.pay(
                transaction: order,
                amount: 10000,
                method: PaymentMethod.transfer,
                requestId: 'fixture-request'))
            .isSuccess,
        isTrue);
    expect((adapter.requests.last.data as Map)['payment_destination_id'], 42);
    expect(
        (await repository.collect(
                transaction: order,
                settlePayment: false,
                detailIds: ['11'],
                paymentAmount: 10000))
            .isSuccess,
        isTrue);
    expect(
        Map<String, String>.fromEntries((adapter.requests.last.data as FormData)
            .fields)['payment_destination_id'],
        '42');
    dio.close(force: true);
  });

  test('detail maps recorded payments without inventing missing legacy fields',
      () {
    final order = TransactionModel.fromJson({
      ..._payload(),
      'payments': [
        {
          'amount': '10000.00',
          'payment_method': 'transfer',
          'paid_at': '2026-10-11T07:00:00Z',
          'payment_destination_label': 'Usaha - Bank A',
          'recorder': {'name': 'Kasir A'},
          'notes': 'DP'
        },
        {'amount': 20000, 'payment_method': 'cash'},
      ]
    }).toEntity();
    expect(order.payments.first.amount, 10000);
    expect(order.payments.first.destinationLabel, 'Usaha - Bank A');
    expect(order.payments.first.recorderName, 'Kasir A');
    expect(order.payments.first.paidAt, DateTime.utc(2026, 10, 11, 7));
    expect(order.payments.last.destinationLabel, isNull);
    expect(order.payments.last.recorderName, isNull);
    expect(order.payments.last.paidAt, isNull);
    expect(order.copyWith(notes: 'updated').payments, order.payments);
  });

  testWidgets('only ready services selectable and layout fits small phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TransactionServiceLines(
                    transaction:
                        TransactionModel.fromJson(_payload()).toEntity(),
                    selectedIds: const {},
                    onToggle: (id, _) => selected = id)))));
    final checkboxes =
        tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
    expect(checkboxes.first.onChanged, isNotNull);
    expect(checkboxes.last.onChanged, isNull);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(selected, '11');
    expect(tester.takeException(), isNull);
    expect(find.textContaining('16:00'), findsOneWidget);
  });

  testWidgets(
      'payment modal returns arbitrary partial amount and note; dismiss is safe',
      (tester) async {
    PaymentEntry? entry;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      entry = await showModalBottomSheet<PaymentEntry>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const PaymentEntrySheet(
                              minimum: 1,
                              maximum: 60000,
                              method: PaymentMethod.cash));
                    },
                    child: const Text('Bayar Saja'))))));
    await tester.tap(find.text('Bayar Saja'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        '60000');
    await tester.enterText(find.byType(TextFormField).first, '10000');
    await tester.enterText(find.byType(TextFormField).last, 'Setengah dulu');
    await tester.tap(find.text('Catat Pembayaran'));
    await tester.pumpAndSettle();
    expect(entry?.amount, 10000);
    expect(entry?.note, 'Setengah dulu');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Bayar Saja'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentEntrySheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image receipt includes each service deadline and remaining bill',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: ReceiptImage(
                    transaction:
                        TransactionModel.fromJson(_payload()).toEntity(),
                    businessName: 'Fixture usaha',
                    businessPhone: '')))));
    expect(find.text('Cuci cepat'), findsOneWidget);
    expect(find.text('Setrika'), findsOneWidget);
    expect(find.text('10/10 16:00 WIB'), findsOneWidget);
    expect(find.text('10/10 18:00 WIB'), findsOneWidget);
    expect(find.text('Sisa tagihan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'native receipt builds all services and estimates without connecting Bluetooth',
      () async {
    final bytes = await ThermalReceiptService()
        .buildReceipt(TransactionModel.fromJson(_payload()).toEntity());
    final receipt = String.fromCharCodes(bytes);
    expect(receipt, contains('Cuci cepat'));
    expect(receipt, contains('Setrika'));
    expect(receipt, contains('10/10/26 16:00'));
    expect(receipt, contains('10/10/26 18:00'));
    expect(receipt, contains('Sisa'));
  });
}
