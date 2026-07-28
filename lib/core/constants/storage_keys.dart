/// Key untuk FlutterSecureStorage & SharedPreferences.
/// Sentralisasi di sini agar tidak ada typo string tersebar di banyak file.
abstract class StorageKeys {
  StorageKeys._();

  // Secure storage (sensitif)
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String currentUser = 'current_user';

  // Shared preferences (non-sensitif)
  static const String rememberLogin = 'remember_login';
  static const String defaultPrinterAddress = 'default_printer_address';
  static const String defaultPrinterName = 'default_printer_name';
  static const String laundryProfile = 'laundry_profile';
  static const String isFirstLaunch = 'is_first_launch';
}
