import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/navigation_write_guard.dart';
import '../widgets/page_visibility_refresh.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/providers/dashboard_providers.dart';
import '../../features/expenses/presentation/providers/expense_providers.dart';
import '../../features/master_data/presentation/providers/master_data_providers.dart';
import '../../features/reports/presentation/providers/report_providers.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';
import '../../features/user_management/presentation/providers/user_management_providers.dart';

/// Refresh read models, not navigation/auth state or draft controllers. The
/// notifier's refresh preserves the selected period/account instead of resetting it.
class ActivePageRefresh extends ConsumerStatefulWidget {
  const ActivePageRefresh({required this.path, required this.child, super.key});
  final String path;
  final Widget child;
  @override
  ConsumerState<ActivePageRefresh> createState() => _ActivePageRefreshState();
}

class _ActivePageRefreshState extends ConsumerState<ActivePageRefresh> {
  bool _cached = false;
  @override
  void initState() {
    super.initState();
    final provider = _provider;
    _cached = provider != null && ref.exists(provider);
  }

  ProviderBase<Object?>? get _provider {
    switch (widget.path) {
      case '/dashboard':
        switch (ref.read(sessionProvider).valueOrNull?.role.apiValue) {
          case 'owner':
            return ownerDashboardProvider;
          case 'kasir':
            return kasirDashboardProvider;
          case 'super_owner':
            return superOwnerDashboardProvider;
        }
      case '/customers':
        return customersProvider;
      case '/services':
        return laundryServicesProvider;
      case '/reports':
        return reportsOverviewProvider;
      case '/users':
        return managedUsersProvider;
      case '/expenses':
        return expensesProvider;
      case '/settings':
        return currentProfileProvider;
    }
    return null;
  }

  Future<void> _refresh() async {
    if (ref.read(navigationWritesProvider) > 0) return;
    final provider = _provider;
    final value = provider == null ? null : ref.read(provider);
    if (value is AsyncValue && value.isLoading) return;
    switch (widget.path) {
      case '/dashboard':
        switch (ref.read(sessionProvider).valueOrNull?.role.apiValue) {
          case 'owner':
            ref.invalidate(ownerFinancialProvider);
            await ref.read(ownerDashboardProvider.notifier).refresh();
          case 'kasir':
            await ref.read(kasirDashboardProvider.notifier).refresh();
          case 'super_owner':
            await ref.read(superOwnerDashboardProvider.notifier).refresh();
        }
      case '/customers':
        await ref.read(customersProvider.notifier).refresh();
      case '/services':
        await ref.read(laundryServicesProvider.notifier).refresh();
      case '/reports':
        await ref.read(reportsOverviewProvider.notifier).refresh();
      case '/users':
        await ref.read(managedUsersProvider.notifier).refresh();
      case '/expenses':
        await ref.read(expensesProvider.notifier).refresh();
      case '/settings':
        ref.invalidate(currentProfileProvider);
        if (ref.read(sessionProvider).valueOrNull?.role.apiValue ==
            'super_owner') {
          ref.invalidate(superOwnerSettingsProvider);
        } else {
          await ref.read(laundrySettingsProvider.notifier).refresh();
        }
    }
  }

  @override
  Widget build(BuildContext context) => PageVisibilityRefresh(
      refreshOnMount: _cached, onVisible: _refresh, child: widget.child);
}
