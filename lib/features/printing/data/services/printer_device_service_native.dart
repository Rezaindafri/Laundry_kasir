import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../domain/entities/printer_device.dart';

class PrinterDeviceService {
  Future<void> ensureReady() async {
    final permissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    final scanGranted =
        permissions[Permission.bluetoothScan]?.isGranted ?? false;
    final connectGranted =
        permissions[Permission.bluetoothConnect]?.isGranted ?? false;
    if (!scanGranted || !connectGranted) {
      throw const PrinterException(
        'Izin Perangkat di sekitar diperlukan. Aktifkan izin tersebut di pengaturan aplikasi.',
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
