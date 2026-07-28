import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/printer_device_service.dart';
import '../../data/services/thermal_receipt_service.dart';

final thermalReceiptServiceProvider =
    Provider<ThermalReceiptService>((ref) => ThermalReceiptService());

final printerDeviceServiceProvider =
    Provider<PrinterDeviceService>((ref) => PrinterDeviceService());
