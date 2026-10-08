/// Konstanta global yang dipakai lintas fitur.
abstract class AppConstants {
  AppConstants._();

  static const String appName = 'KarsaOne';
  static const String appLogoAsset = 'assets/brand/karsaone_logo.png';

  /// Ganti sesuai environment backend.
  /// Untuk device fisik, arahkan ke IP LAN komputer yang menjalankan Laravel.
  static const String baseUrl = 'http://192.168.1.12/api-indafri-laundry/public/api';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Jika true, seluruh AuthRemoteDataSource memakai data dummy
  /// (tidak melakukan network call). Set false saat backend siap.
  static const bool useMockApi = false;

}
