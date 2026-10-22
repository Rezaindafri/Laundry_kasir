import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../domain/entities/printer_device.dart';

class PrinterDeviceService {
  PrinterDeviceService({Future<bool> Function()? bluetoothEnabled})
      : _bluetoothEnabled = bluetoothEnabled ?? _readBluetoothEnabled;

  final Future<bool> Function() _bluetoothEnabled;
  Future<void>? _readinessCheck;

  static Future<bool> _readBluetoothEnabled() =>
      PrintBluetoothThermal.bluetoothEnabled;

  Future<void> ensureReady() => _readinessCheck ??=
      _ensureReady().whenComplete(() => _readinessCheck = null);

  Future<void> _ensureReady() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw const PrinterException(
        'Cetak Bluetooth saat ini hanya didukung pada aplikasi Android.',
      );
    }

    // print_bluetooth_thermal cancels Android discovery before every RFCOMM
    // connection. cancelDiscovery() needs SCAN on Android 12+, even though
    // this app only lists paired devices. Its permission getter checks only
    // CONNECT, so it cannot verify all permissions needed for printing.
    // permission_handler maps these to legacy Bluetooth on Android < 12;
    // no location permission or active discovery is introduced here.
    final permissions = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    if (permissions[Permission.bluetoothConnect] != PermissionStatus.granted ||
        permissions[Permission.bluetoothScan] != PermissionStatus.granted) {
      throw const PrinterException(
        'Izin perangkat Bluetooth diperlukan. Aktifkan izin "Perangkat di sekitar" di pengaturan aplikasi.',
      );
    }
    if (!await _bluetoothEnabled()) {
      throw const PrinterException(
        'Bluetooth belum aktif. Aktifkan Bluetooth terlebih dahulu.',
      );
    }
  }

  Future<List<PrinterDevice>> getPairedDevices() async {
    await ensureReady();
    final paired = await PrintBluetoothThermal.pairedBluetooths;
    return paired
        .map((device) =>
            PrinterDevice(name: device.name, macAddress: device.macAdress))
        .toList(growable: false);
  }
}
