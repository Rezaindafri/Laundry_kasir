import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/constants/storage_keys.dart';
import 'package:laundry_management_system/core/error/exceptions.dart';
import 'package:laundry_management_system/core/network/dio_client.dart';
import 'package:laundry_management_system/core/utils/business_time.dart';
import 'package:laundry_management_system/features/expenses/data/models/expense_model.dart';
import 'package:laundry_management_system/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:laundry_management_system/features/transactions/data/models/transaction_model.dart';
import 'package:laundry_management_system/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:laundry_management_system/features/transactions/presentation/widgets/transaction_proof_dialog.dart';

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.status);
  final int status;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return status == 200
        ? ResponseBody.fromBytes(
            [1, 2, 3],
            status,
            headers: {
              Headers.contentTypeHeader: ['image/png'],
            },
          )
        : ResponseBody.fromString(
            '{"message":"Denied"}',
            status,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UTC/WIB midnight and month boundary preserve the instant', () {
    final before =
        BusinessTime.wallTime(DateTime.parse('2026-09-30T16:59:59Z'));
    final after = BusinessTime.wallTime(DateTime.parse('2026-09-30T17:00:00Z'));
    expect([before.month, before.day, before.hour], [9, 30, 23]);
    expect([after.month, after.day, after.hour], [10, 1, 0]);
    expect(BusinessTime.dateParameter(after), '2026-10-01');
    expect(
      BusinessTime.utcFromWallTime(after),
      DateTime.parse('2026-09-30T17:00:00Z'),
    );
    expect(
      BusinessTime.wallTime(DateTime.parse('2026-10-01T01:00:00+08:00')),
      after,
    );
  });

  test('expense picker fields are serialized as an explicit UTC instant', () {
    final input = ExpenseInput(
      amount: 1000,
      category: 'Fixture',
      description: null,
      occurredAt: BusinessTime.utcFromWallTime(DateTime(2026, 10, 1, 0, 30)),
    );
    expect(input.toJson()['occurred_at'], '2026-09-30T17:30:00.000Z');
  });

  test('proof metadata survives model/entity/copy, not sent on create', () {
    final model = TransactionModel.fromJson({
      'id': 1,
      'created_at': '2026-10-01T00:00:00Z',
      'has_proof_image': true,
    });
    expect(model.toEntity().copyWith(paidAmount: 1000).hasProofImage, isTrue);
    expect(model.toJson(forRequest: false)['has_proof_image'], isTrue);
    expect(
      model.toJson(forRequest: true).containsKey('has_proof_image'),
      isFalse,
    );
    expect(
      TransactionModel.fromJson(
        {
          'has_proof_image': false,
          'proof_image_path': 'proofs/old.png',
        },
      ).hasProofImage,
      isFalse,
    );
  });

  for (final status in [200, 401, 403, 404]) {
    test('proof download $status uses bearer without a public/token URL',
        () async {
      FlutterSecureStorage.setMockInitialValues({
        StorageKeys.accessToken: 'fixture-token',
      });
      final client =
          DioClient.forTesting(secureStorage: const FlutterSecureStorage());
      final adapter = _BytesAdapter(status);
      client.dio.httpClientAdapter = adapter;
      final source = TransactionRemoteDataSourceImpl(client.dio);
      try {
        if (status == 200) {
          expect(await source.downloadProof('1'), [1, 2, 3]);
        } else {
          await expectLater(
            source.downloadProof('1'),
            throwsA(
              isA<ServerException>()
                  .having((e) => e.statusCode, 'status', status),
            ),
          );
        }
        expect(adapter.request!.path, '/transactions/1/proof');
        expect(adapter.request!.queryParameters, isEmpty);
        expect(
          adapter.request!.headers['Authorization'],
          'Bearer fixture-token',
        );
      } finally {
        await client.dispose();
      }
    });
  }

  testWidgets('authorized proof dialog displays image and closes safely',
      (tester) async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aE1cAAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transactionProofProvider('1').overrideWith((ref) async => png),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const TransactionProofDialog(
                    transactionId: '1',
                  ),
                ),
                child: const Text('Buka'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Bukti pengambilan'), findsNothing);
  });
}
