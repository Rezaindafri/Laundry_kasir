import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/printer_device_service.dart';
import '../../data/services/thermal_receipt_service.dart';

final thermalReceiptServiceProvider =
    Provider<ThermalReceiptService>((ref) => ThermalReceiptService());

final printerDeviceServiceProvider =
    Provider<PrinterDeviceService>((ref) => PrinterDeviceService());

/// Prevents a second tap from opening a concurrent Bluetooth connection while
/// the first receipt is still being transmitted.
final receiptPrintingProvider = StateProvider<bool>((ref) => false);

/// Prevents opening the share sheet repeatedly while the receipt image is
/// being rendered.
final receiptSharingProvider = StateProvider<bool>((ref) => false);
