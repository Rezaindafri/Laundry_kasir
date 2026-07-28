import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/laundry_settings.dart';

class LocalSettingsRepository {
  final SharedPreferences preferences;
  const LocalSettingsRepository(this.preferences);
  static const _name = 'settings_laundry_name';
  static const _phone = 'settings_laundry_phone';
  static const _address = 'settings_laundry_address';
  static const _paper = 'settings_paper_size';
  static const _printer = 'settings_default_printer';
  LaundrySettings load() => LaundrySettings(
      businessName: preferences.getString(_name) ?? 'Clean Fresh Laundry',
      phone: preferences.getString(_phone) ?? '',
      address: preferences.getString(_address) ?? '',
      paperSize: preferences.getString(_paper) ?? '58 mm',
      defaultPrinter: preferences.getString(_printer),);
  Future<void> save(LaundrySettings value) async {
    await preferences.setString(_name, value.businessName);
    await preferences.setString(_phone, value.phone);
    await preferences.setString(_address, value.address);
    await preferences.setString(_paper, value.paperSize);
    if (value.defaultPrinter == null || value.defaultPrinter!.isEmpty) {
      await preferences.remove(_printer);
    } else {
      await preferences.setString(_printer, value.defaultPrinter!);
    }
  }
}
