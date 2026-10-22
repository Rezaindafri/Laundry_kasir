import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:laundry_management_system/features/printing/data/services/printer_device_service_native.dart';
import 'package:laundry_management_system/features/printing/data/services/thermal_receipt_service_native.dart';
import 'package:laundry_management_system/features/printing/domain/entities/printer_device.dart';
import 'package:laundry_management_system/features/transactions/domain/entities/transaction_entity.dart';

const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

class _DeniedPrinterService extends PrinterDeviceService {
  int checks = 0;

  @override
  Future<void> ensureReady() async {
    checks++;
    throw const PrinterException('Izin perangkat Bluetooth diperlukan.');
  }
}

TransactionEntity _transaction() => TransactionEntity(
      id: '1',
      invoice: 'INV-PRINTER-TEST',
      customerId: '1',
      customerName: 'Pelanggan tes',
      customerPhone: '',
      serviceName: 'Layanan tes',
      quantity: 1,
      quantityUnit: 'item',
      unitPrice: 10000,
      expressFee: 0,
      total: 10000,
      paidAmount: 0,
      paymentMethod: PaymentMethod.cash,
      paymentStatus: PaymentStatus.unpaid,
      laundryStatus: LaundryStatus.received,
      createdAt: DateTime.utc(2026, 10, 21),
      estimatedFinishAt: DateTime.utc(2026, 10, 22),
    );

PrinterDeviceService _androidPrinter() =>
    PrinterDeviceService(bluetoothEnabled: () async => true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissions, null);
  });

  test('readiness requests CONNECT and SCAN, even with CONNECT already granted',
      () async {
    List<int>? requested;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissions, (call) async {
      expect(call.method, 'requestPermissions');
      requested = List<int>.from(call.arguments as List);
      return {for (final id in requested!) id: PermissionStatus.granted.index};
    });

    await _androidPrinter().ensureReady();

    expect(requested,
        [Permission.bluetoothConnect.value, Permission.bluetoothScan.value]);
    expect(requested, isNot(contains(Permission.location.value)));
  });

  test('denied SCAN blocks printing readiness instead of silently connecting',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            _permissions,
            (call) async => {
                  Permission.bluetoothConnect.value:
                      PermissionStatus.granted.index,
                  Permission.bluetoothScan.value: PermissionStatus.denied.index,
                });

    await expectLater(
      _androidPrinter().ensureReady(),
      throwsA(isA<PrinterException>().having(
        (error) => error.message,
        'message',
        contains('Perangkat di sekitar'),
      )),
    );
  });

  test('concurrent readiness checks share one permission request', () async {
    final response = Completer<Map<int, int>>();
    var requests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissions, (call) {
      requests++;
      return response.future;
    });
    final service = _androidPrinter();

    final first = service.ensureReady();
    final second = service.ensureReady();
    expect(identical(first, second), isTrue);
    response.complete({
      Permission.bluetoothConnect.value: PermissionStatus.granted.index,
      Permission.bluetoothScan.value: PermissionStatus.granted.index,
    });
    await Future.wait([first, second]);
    expect(requests, 1);
  });

  test(
      'permission can be retried after denial without a stuck readiness future',
      () async {
    var granted = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            _permissions,
            (call) async => {
                  Permission.bluetoothConnect.value:
                      PermissionStatus.granted.index,
                  Permission.bluetoothScan.value: granted
                      ? PermissionStatus.granted.index
                      : PermissionStatus.denied.index,
                });
    final service = _androidPrinter();

    await expectLater(service.ensureReady(), throwsA(isA<PrinterException>()));
    granted = true;
    await service.ensureReady();
  });

  test('print itself rechecks readiness and releases its lock after denial',
      () async {
    final readiness = _DeniedPrinterService();
    final service = ThermalReceiptService(printerDeviceService: readiness);

    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(
        service.print(_transaction(), macAddress: '01:23:45:67:89:AB'),
        throwsA(isA<PrinterException>().having(
          (error) => error.message,
          'message',
          'Izin perangkat Bluetooth diperlukan.',
        )),
      );
    }
    expect(readiness.checks, 2);
  });

  test('invalid saved printer address is rejected before opening Bluetooth',
      () async {
    final readiness = _DeniedPrinterService();
    final service = ThermalReceiptService(printerDeviceService: readiness);

    await expectLater(
      service.print(_transaction(), macAddress: ''),
      throwsA(isA<PrinterException>().having(
        (error) => error.message,
        'message',
        contains('alamat printer tidak valid'),
      )),
    );
    expect(readiness.checks, 0);
  });
}
