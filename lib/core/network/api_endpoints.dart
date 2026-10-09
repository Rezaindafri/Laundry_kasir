/// Kumpulan path endpoint REST API. Base URL diatur terpisah di
/// AppConstants.baseUrl / DioClient. Sesuaikan saat backend Laravel
/// sudah tersedia — struktur ini mengikuti konvensi resource Laravel.
abstract class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String profile = '/profile';
  static const String profilePassword = '/profile/password';

  // Users
  static const String users = '/users';
  static String userById(String id) => '/users/$id';
  static String userCredentials(String id) => '/users/$id/credentials';
  static String userStatus(String id) => '/users/$id/status';

  // Customers
  static const String customers = '/customers';
  static String customerById(String id) => '/customers/$id';

  // Services
  static const String services = '/services';
  static String serviceById(String id) => '/services/$id';

  // Transactions
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';
  static String updateStatus(String id) => '/transactions/$id/status';
  static String payment(String id) => '/transactions/$id/payment';
  static String collection(String id) => '/transactions/$id/collection';
  static String transactionProof(String id) => '/transactions/$id/proof';

  // Dashboard & Reports
  static const String dashboardOwner = '/dashboard/owner';
  static const String dashboardOwnerFinancial = '/dashboard/owner/financial';
  static const String dashboardKasir = '/dashboard/kasir';
  static const String dashboardSuperOwner = '/dashboard/super-owner';
  static const String reportsOverview = '/reports/overview';
  static const String reportsExport = '/reports/export';
  static const String auditLogs = '/audit-logs';

  // Owner expenses
  static const String expenses = '/expenses';
  static String expenseById(String id) => '/expenses/$id';

  // Settings
  static const String settings = '/settings';
  static const String backup = '/settings/backup';
  static const String restore = '/settings/restore';
  static const String systemSettings = '/system-settings';
  static const String accountPolicy = '/account-policy';
}
