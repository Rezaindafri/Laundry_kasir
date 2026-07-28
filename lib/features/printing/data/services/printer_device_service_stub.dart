import '../../domain/entities/printer_device.dart';

class PrinterDeviceService {
  Future<void> ensureReady() async {
    throw const PrinterException(
      'Pemilihan printer Bluetooth hanya tersedia di aplikasi Android.',
    );
  }

  Future<List<PrinterDevice>> getPairedDevices() async {
    await ensureReady();
    return const [];
  }
}
