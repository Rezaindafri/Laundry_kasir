import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/kasir_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/super_owner_dashboard_screen.dart';
import '../../features/master_data/presentation/screens/customers_screen.dart';
import '../../features/master_data/presentation/screens/laundry_services_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/screens/qr_scanner_screen.dart';
import '../../features/user_management/presentation/screens/user_management_screen.dart';
import '../../shared/enums/user_role.dart';

abstract class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const customers = '/customers';
  static const services = '/services';
  static const transactions = '/transactions';
  static const qrScanner = '/scan-qr';
  static const reports = '/reports';
  static const users = '/users';
  static const settings = '/settings';
}

/// Menjembatani AsyncNotifier (Riverpod) dengan GoRouter's
/// refreshListenable, supaya router otomatis redirect setiap kali
/// sessionProvider berubah (login/logout/auto-login selesai).
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _SessionRefreshListenable(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // Masih mengecek Auto Login -> tetap di Splash Screen.
      if (session.isLoading) {
        return isSplash ? null : AppRoutes.splash;
      }

      final user = session.valueOrNull;
      final isLoggedIn = user != null;

      if (!isLoggedIn) {
        return isLoggingIn ? null : AppRoutes.login;
      }

      // Sudah login tapi masih di Splash/Login -> lempar ke dashboard.
      if (isSplash || isLoggingIn) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) {
          final user = ref.read(sessionProvider).valueOrNull;
          if (user == null) return const LoginScreen();

          return switch (user.role) {
            UserRole.superOwner => SuperOwnerDashboardScreen(user: user),
            UserRole.owner => OwnerDashboardScreen(user: user),
            UserRole.kasir => KasirDashboardScreen(user: user),
          };
        },
      ),
      GoRoute(
        path: AppRoutes.customers,
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactions,
        builder: (context, state) => const TransactionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.qrScanner,
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        redirect: (context, state) =>
            ref.read(sessionProvider).valueOrNull?.role.canViewProfitReports ==
                    true
                ? null
                : AppRoutes.dashboard,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.users,
        redirect: (context, state) =>
            ref.read(sessionProvider).valueOrNull?.role.canManageUsers == true
                ? null
                : AppRoutes.dashboard,
        builder: (context, state) => const UserManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.services,
        redirect: (context, state) {
          final role = ref.read(sessionProvider).valueOrNull?.role;
          return role?.canManageServicePrice == true
              ? null
              : AppRoutes.dashboard;
        },
        builder: (context, state) => const LaundryServicesScreen(),
      ),
    ],
  );
});
