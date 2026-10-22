import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_management_system/core/network/dio_client.dart';
import 'package:laundry_management_system/core/network/request_failure_notice.dart';
import 'package:laundry_management_system/core/widgets/request_failure_listener.dart';

class _BrokenAdapter implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    throw DioException(
        requestOptions: options, type: DioExceptionType.receiveTimeout);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.badCertificate
  ]) {
    test('transport failure $type has a safe read notification', () {
      final notice = RequestFailureNotice.fromError(DioException(
          requestOptions: RequestOptions(path: '/reports'), type: type));
      expect(
          notice?.message, 'Gagal memuat data. Periksa koneksi dan coba lagi.');
    });
  }

  test(
      'cancel, rejected login, validation, and silent prefetch do not notify globally',
      () {
    final options = RequestOptions(path: '/fixture');
    for (final status in [401, 403, 422, 429]) {
      expect(
          RequestFailureNotice.fromError(DioException(
              requestOptions: options,
              response: Response(requestOptions: options, statusCode: status),
              type: DioExceptionType.badResponse)),
          isNull);
    }
    expect(
        RequestFailureNotice.fromError(DioException(
            requestOptions: options, type: DioExceptionType.cancel)),
        isNull);
    expect(
        RequestFailureNotice.fromError(DioException(
            requestOptions: RequestOptions(
                path: '/fixture', extra: {'silentFailure': true}),
            type: DioExceptionType.connectionError)),
        isNull);
    final write = RequestOptions(path: '/payments', method: 'POST');
    final notice = RequestFailureNotice.fromError(DioException(
        requestOptions: write,
        response: Response(requestOptions: write, statusCode: 500),
        type: DioExceptionType.badResponse));
    expect(notice?.isWrite, isTrue);
    expect(notice?.message, contains('Periksa data terbaru'));
  });

  test('failed write has finite timeouts and is not automatically retried',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    final client =
        DioClient.forTesting(secureStorage: const FlutterSecureStorage());
    final adapter = _BrokenAdapter();
    client.dio.httpClientAdapter = adapter;
    final notices = <RequestFailureNotice>[];
    final subscription = client.requestFailureEvents.listen(notices.add);
    await expectLater(client.dio.post('/payments', data: {'amount': 10000}),
        throwsA(isA<DioException>()));
    await Future<void>.delayed(Duration.zero);
    expect(adapter.calls, 1);
    expect(notices.single.isWrite, isTrue);
    expect(client.dio.options.sendTimeout, isNotNull);
    expect(client.dio.options.receiveTimeout, isNotNull);
    await subscription.cancel();
    await client.dispose();
  });

  testWidgets(
      'parallel failures show one bounded notification and unsubscribe on disposal',
      (tester) async {
    final events = StreamController<RequestFailureNotice>.broadcast();
    final messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: messenger,
        home: RequestFailureListener(
            events: events.stream,
            messengerKey: messenger,
            child: const Scaffold(body: Text('Halaman fixture')))));
    for (var i = 0; i < 5; i++) {
      events.add(const RequestFailureNotice(isWrite: false));
    }
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat data. Periksa koneksi dan coba lagi.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    events.add(const RequestFailureNotice(isWrite: true));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await events.close();
  });
}
