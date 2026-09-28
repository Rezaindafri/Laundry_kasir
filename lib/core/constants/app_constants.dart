/// Konstanta global yang dipakai lintas fitur.
abstract class AppConstants {
  AppConstants._();

  static const String appName = 'Clean Fresh Laundry';

  /// Ganti sesuai environment backend.
  /// Untuk device fisik, arahkan ke IP LAN komputer yang menjalankan Laravel.
  static const String baseUrl = 'http://192.168.1.7/api-indafri-laundry/public/api';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Jika true, seluruh AuthRemoteDataSource memakai data dummy
  /// (tidak melakukan network call). Set false saat backend siap.
  static const bool useMockApi = false;

  static const String invoicePrefix = 'INV';
  static const int paperWidthMm = 58;
}
