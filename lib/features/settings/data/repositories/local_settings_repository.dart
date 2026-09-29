import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_keys.dart';
import '../../domain/entities/laundry_settings.dart';

class LocalSettingsRepository {
  final SharedPreferences preferences;
  const LocalSettingsRepository(this.preferences);
  static const _name = 'settings_laundry_name';
  static const _phone = 'settings_laundry_phone';
  static const _address = 'settings_laundry_address';
  static const _paper = 'settings_paper_size';
  static const _printer = 'settings_default_printer';
  static const _printerName = StorageKeys.defaultPrinterName;
  String _businessKey(String key, String? ownerId) =>
      ownerId == null || ownerId.isEmpty ? key : '$key.$ownerId';

  LaundrySettings load({String? ownerId}) => LaundrySettings(
        businessName: preferences.getString(_businessKey(_name, ownerId)) ??
            'Clean Fresh Laundry',
        phone: preferences.getString(_businessKey(_phone, ownerId)) ?? '',
        address: preferences.getString(_businessKey(_address, ownerId)) ?? '',
        paperSize: preferences.getString(_paper) ?? '58 mm',
        defaultPrinter: preferences.getString(_printer),
        defaultPrinterName: preferences.getString(_printerName),
      );
  Future<void> save(LaundrySettings value, {String? ownerId}) async {
    await preferences.setString(_businessKey(_name, ownerId), value.businessName);
    await preferences.setString(_businessKey(_phone, ownerId), value.phone);
    await preferences.setString(_businessKey(_address, ownerId), value.address);
    await preferences.setString(_paper, value.paperSize);
    if (value.defaultPrinter == null || value.defaultPrinter!.isEmpty) {
      await preferences.remove(_printer);
      await preferences.remove(_printerName);
    } else {
      await preferences.setString(_printer, value.defaultPrinter!);
      if (value.defaultPrinterName == null ||
          value.defaultPrinterName!.isEmpty) {
        await preferences.remove(_printerName);
      } else {
        await preferences.setString(_printerName, value.defaultPrinterName!);
      }
    }
  }
}
