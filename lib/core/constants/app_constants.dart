/// Konstanta global yang dipakai lintas fitur.
abstract class AppConstants {
  AppConstants._();

  static const String appName = 'Clean Fresh Laundry';

  /// Ganti sesuai environment backend. Untuk sekarang masih mock/dummy,
  /// backend Laravel menyusul dan tinggal ganti base URL ini.
  static const String baseUrl = 'https://api.laundryapp.test/api/v1';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Jika true, seluruh AuthRemoteDataSource memakai data dummy
  /// (tidak melakukan network call). Set false saat backend siap.
  static const bool useMockApi = true;

  static const String invoicePrefix = 'INV';
  static const int paperWidthMm = 58;
}
