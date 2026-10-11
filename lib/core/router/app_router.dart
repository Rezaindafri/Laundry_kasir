import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'active_page_refresh.dart';
import '../widgets/page_visibility_refresh.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/providers/splash_intro_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/audit/presentation/screens/audit_logs_screen.dart';
import '../../features/dashboard/presentation/screens/kasir_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/super_owner_dashboard_screen.dart';
import '../../features/dashboard/presentation/widgets/dashboard_shell.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/master_data/presentation/screens/customers_screen.dart';
import '../../features/master_data/presentation/screens/laundry_services_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/screens/qr_scanner_screen.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
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
  static const collections = '/collections';
  static const collectionSettlement = '/collection-settlement';
  static const qrScanner = '/scan-qr';
  static const reports = '/reports';
  static const users = '/users';
  static const auditLogs = '/audit-logs';
  static const expenses = '/expenses';
  static const settings = '/settings';
}

/// Informasi arah perpindahan antar-tab yang dikirim oleh bottom navigation.
class AppTabTransition {
  final bool movesLeft;

  const AppTabTransition({required this.movesLeft});
}

/// Authenticated-route lifecycle: pause the scanner while another page covers it.
final appRouteObserver = RouteObserver<ModalRoute<dynamic>>();

Page<void> _tabPage(GoRouterState state, Widget child) {
  child = ActivePageRefresh(path: state.uri.path, child: child);
  final transition =
      state.extra is AppTabTransition ? state.extra as AppTabTransition : null;
  if (transition == null) {
    return NoTransitionPage<void>(key: state.pageKey, child: child);
  }

  final begin =
      transition.movesLeft ? const Offset(0.28, 0) : const Offset(-0.28, 0);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
      ),
      child: child,
    ),
  );
}

/// Menjembatani AsyncNotifier (Riverpod) dengan GoRouter's
/// refreshListenable, supaya router otomatis redirect saat sesi berubah
/// atau animasi splash sudah selesai.
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionProvider, (_, __) => notifyListeners());
    ref.listen(splashIntroCompletedProvider, (_, __) => notifyListeners());
    ref.listen(logoutInProgressProvider, (_, __) => notifyListeners());
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
      final isLoggingOut = ref.read(logoutInProgressProvider);

      // Logout selalu melewati splash dan tetap di sana sampai sesi lokal
      // selesai dibersihkan, walaupun animasi lebih cepat selesai.
      if (isLoggingOut) {
        return isSplash ? null : AppRoutes.splash;
      }

      // Beri kesempatan animasi pembuka selesai meski sesi lokal cepat terbaca.
      if (isSplash && !ref.read(splashIntroCompletedProvider)) {
        return null;
      }

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
      ShellRoute(
        observers: [appRouteObserver, pageRefreshObserver],
        builder: (context, state, child) => PersistentTabShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) {
              final user = ref.read(sessionProvider).valueOrNull;
              if (user == null) {
                return NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const LoginScreen(),
                );
              }

              final child = switch (user.role) {
                UserRole.superOwner => SuperOwnerDashboardScreen(user: user),
                UserRole.owner => OwnerDashboardScreen(user: user),
                UserRole.kasir => KasirDashboardScreen(user: user),
              };
              return _tabPage(state, child);
            },
          ),
          GoRoute(
            path: AppRoutes.customers,
            redirect: (context, state) {
              final role = ref.read(sessionProvider).valueOrNull?.role;
              return role == UserRole.owner || role == UserRole.kasir
                  ? null
                  : AppRoutes.dashboard;
            },
            pageBuilder: (context, state) => _tabPage(
              state,
              CustomersScreen(
                key: ValueKey(state.uri.toString()),
                openCreateForm: state.uri.queryParameters['create'] == 'true',
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.transactions,
            redirect: (context, state) {
              final role = ref.read(sessionProvider).valueOrNull?.role;
              return role == UserRole.owner || role == UserRole.kasir
                  ? null
                  : AppRoutes.dashboard;
            },
            pageBuilder: (context, state) => _tabPage(
              state,
              TransactionsScreen(
                key: ValueKey(state.uri.toString()),
                initialFilter: TransactionListFilterLabel.fromQuery(
                  state.uri.queryParameters['filter'],
                ),
                initialDateRange: _transactionDateRange(state),
                initialCashierId: state.uri.queryParameters['cashier_id'],
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.reports,
            redirect: (context, state) => ref
                        .read(sessionProvider)
                        .valueOrNull
                        ?.role
                        .canViewProfitReports ==
                    true
                ? null
                : AppRoutes.dashboard,
            pageBuilder: (context, state) => _tabPage(
              state,
              const ReportsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => _tabPage(
              state,
              const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.users,
            redirect: (context, state) =>
                ref.read(sessionProvider).valueOrNull?.role.canManageUsers ==
                        true
                    ? null
                    : AppRoutes.dashboard,
            pageBuilder: (context, state) {
              final requestedRole = state.uri.queryParameters['create'];
              final initialCreateRole = requestedRole == 'owner'
                  ? UserRole.owner
                  : requestedRole == 'kasir'
                      ? UserRole.kasir
                      : null;
              return _tabPage(
                state,
                UserManagementScreen(initialCreateRole: initialCreateRole),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.qrScanner,
            redirect: (context, state) {
              final role = ref.read(sessionProvider).valueOrNull?.role;
              return role == UserRole.owner || role == UserRole.kasir
                  ? null
                  : AppRoutes.dashboard;
            },
            builder: (context, state) => const QrScannerScreen(),
          ),
          GoRoute(
            path: AppRoutes.collections,
            redirect: (context, state) {
              final role = ref.read(sessionProvider).valueOrNull?.role;
              return role == UserRole.owner || role == UserRole.kasir
                  ? null
                  : AppRoutes.dashboard;
            },
            builder: (context, state) => const TransactionsScreen(
              isCollectionMode: true,
            ),
          ),
          GoRoute(
            path: AppRoutes.collectionSettlement,
            redirect: (context, state) {
              final role = ref.read(sessionProvider).valueOrNull?.role;
              return role == UserRole.owner || role == UserRole.kasir
                  ? null
                  : AppRoutes.dashboard;
            },
            builder: (context, state) {
              final transaction = state.extra;
              if (transaction is TransactionEntity) {
                return CollectionSettlementScreen(transaction: transaction);
              }
              return const TransactionsScreen(isCollectionMode: true);
            },
          ),
          GoRoute(
            path: AppRoutes.services,
            redirect: (context, state) {
              final role = ref.read(sessionProvider).valueOrNull?.role;
              return role?.canManageServicePrice == true
                  ? null
                  : AppRoutes.dashboard;
            },
            builder: (context, state) => const ActivePageRefresh(
                path: AppRoutes.services, child: LaundryServicesScreen()),
          ),
          GoRoute(
            path: AppRoutes.auditLogs,
            redirect: (context, state) =>
                ref.read(sessionProvider).valueOrNull?.role == UserRole.owner
                    ? null
                    : AppRoutes.dashboard,
            builder: (context, state) => const AuditLogsScreen(),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            redirect: (context, state) =>
                ref.read(sessionProvider).valueOrNull?.role == UserRole.owner
                    ? null
                    : AppRoutes.dashboard,
            builder: (context, state) => const ActivePageRefresh(
                path: AppRoutes.expenses, child: ExpensesScreen()),
          ),
        ],
      ),
    ],
  );
});

DateTimeRange? _transactionDateRange(GoRouterState state) {
  final from = DateTime.tryParse(state.uri.queryParameters['from'] ?? '');
  final to = DateTime.tryParse(state.uri.queryParameters['to'] ?? '');
  if (from == null || to == null || to.isBefore(from)) return null;
  return DateTimeRange(start: from, end: to);
}
