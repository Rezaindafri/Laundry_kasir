import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../domain/entities/printer_device.dart';

class PrinterDeviceService {
  Future<void> ensureReady() async {
    if (!Platform.isAndroid) {
      throw const PrinterException(
        'Cetak Bluetooth saat ini hanya didukung pada aplikasi Android.',
      );
    }

    // The application only reads *paired* devices and opens an RFCOMM
    // connection; it does not discover nearby devices. Requiring SCAN here
    // made printing fail when a user denied an unnecessary permission.
    var permissionGranted =
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!permissionGranted) {
      permissionGranted = await Permission.bluetoothConnect.request().isGranted;
    }
    if (!permissionGranted) {
      throw const PrinterException(
        'Izin perangkat Bluetooth diperlukan. Aktifkan izin "Perangkat di sekitar" di pengaturan aplikasi.',
      );
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
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
