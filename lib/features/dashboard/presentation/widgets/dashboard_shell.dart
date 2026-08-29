import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class DashboardShell extends ConsumerWidget {
  final UserEntity user;
  final Widget body;
  final String title;

  const DashboardShell({
    required this.user,
    required this.body,
    required this.title,
    super.key,
  });

  List<_BottomNavItem> _navItems() {
    switch (user.role) {
      case UserRole.kasir:
        return const [
          _BottomNavItem(
            'Beranda',
            Icons.home_outlined,
            Icons.home_rounded,
            AppRoutes.dashboard,
          ),
          _BottomNavItem(
            'Transaksi',
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            AppRoutes.transactions,
          ),
          _BottomNavItem(
            'Scan QR',
            Icons.qr_code_scanner_outlined,
            Icons.qr_code_scanner_rounded,
            AppRoutes.qrScanner,
          ),
          _BottomNavItem(
            'Pelanggan',
            Icons.people_outline,
            Icons.people_rounded,
            AppRoutes.customers,
          ),
          _BottomNavItem(
            'Setting',
            Icons.settings_outlined,
            Icons.settings_rounded,
            AppRoutes.settings,
          ),
        ];
      case UserRole.owner:
      case UserRole.superOwner:
        return const [
          _BottomNavItem(
            'Beranda',
            Icons.home_outlined,
            Icons.home_rounded,
            AppRoutes.dashboard,
          ),
          _BottomNavItem(
            'Transaksi',
            Icons.receipt_long_outlined,
            Icons.receipt_long_rounded,
            AppRoutes.transactions,
          ),
          _BottomNavItem(
            'Scan QR',
            Icons.qr_code_scanner_outlined,
            Icons.qr_code_scanner_rounded,
            AppRoutes.qrScanner,
          ),
          _BottomNavItem(
            'Laporan',
            Icons.bar_chart_outlined,
            Icons.bar_chart_rounded,
            AppRoutes.reports,
          ),
          _BottomNavItem(
            'Setting',
            Icons.settings_outlined,
            Icons.settings_rounded,
            AppRoutes.settings,
          ),
        ];
    }
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouter.of(context).state.matchedLocation;
    final items = _navItems();

    final index = items.indexWhere((item) => item.route == location);
    if (index != -1) return index;

    if (location == AppRoutes.dashboard) return 0;
    if (location.startsWith(AppRoutes.transactions)) return 1;
    if (location == AppRoutes.qrScanner) return 2;
    if (location == AppRoutes.customers) return 3;
    if (location == AppRoutes.reports) return 3;
    if (location == AppRoutes.settings) return 4;

    return 0;
  }

  void _onItemTapped(BuildContext context, String route) {
    if (GoRouter.of(context).state.matchedLocation != route) {
      context.push(route);
    }
  }

  Future<void> _handleSystemBack(BuildContext context) async {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Keluar aplikasi?'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Aplikasi'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(sessionProvider.notifier).logout();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navItems = _navItems();
    final selectedIndex = _selectedIndex(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, style: AppTextStyles.title),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Keluar',
              onPressed: () => _confirmLogout(context, ref),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: _AppDrawer(user: user),
        body: body,
        bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.card,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(navItems.length, (index) {
                final item = navItems[index];
                final isSelected = selectedIndex == index;
                final isCenter = index == 2;

                return Expanded(
                  child: isCenter
                      ? _QrNavigationItem(
                          item: item,
                          isSelected: isSelected,
                          onTap: () => _onItemTapped(context, item.route),
                        )
                      : _NavigationItem(
                          item: item,
                          isSelected: isSelected,
                          onTap: () => _onItemTapped(context, item.route),
                        ),
                );
              }),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _BottomNavItem(this.label, this.icon, this.activeIcon, this.route);
}

class _NavigationItem extends StatelessWidget {
  final _BottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 23,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      );
}

class _QrNavigationItem extends StatelessWidget {
  final _BottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _QrNavigationItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Transform.translate(
          offset: const Offset(0, -22),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryDark : AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.card, width: 3),
            ),
            child: Icon(item.activeIcon, color: Colors.white, size: 27),
          ),
        ),
      );
}

class _AppDrawer extends StatelessWidget {
  final UserEntity user;

  const _AppDrawer({required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user.role;
    final menuItems = <_MenuItem>[
      const _MenuItem('Dashboard', Icons.dashboard_outlined, AppRoutes.dashboard),
      const _MenuItem(
        'Transaksi',
        Icons.point_of_sale_outlined,
        AppRoutes.transactions,
      ),
      const _MenuItem('Pelanggan', Icons.people_outline, AppRoutes.customers),
      if (role.canManageServicePrice)
        const _MenuItem(
          'Layanan Laundry',
          Icons.local_laundry_service_outlined,
          AppRoutes.services,
        ),
      const _MenuItem(
        'Scan QR',
        Icons.qr_code_scanner_outlined,
        AppRoutes.qrScanner,
      ),
      const _MenuItem(
        'Riwayat Transaksi',
        Icons.history_outlined,
        AppRoutes.transactions,
      ),
      if (role.canViewProfitReports)
        const _MenuItem('Laporan', Icons.bar_chart_outlined, AppRoutes.reports),
      if (role.canManageUsers)
        const _MenuItem(
          'Manajemen User',
          Icons.manage_accounts_outlined,
          AppRoutes.users,
        ),
      if (role.canBackupRestore)
        const _MenuItem('Backup / Restore', Icons.backup_outlined),
      const _MenuItem('Pengaturan', Icons.settings_outlined, AppRoutes.settings),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.secondary,
                    foregroundColor: AppColors.primary,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: AppTextStyles.title.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: AppTextStyles.title, maxLines: 1),
                        Text(role.label, style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: menuItems.map((item) => ListTile(
                  leading: Icon(item.icon, color: AppColors.textSecondary),
                  title: Text(item.label, style: AppTextStyles.body),
                  enabled: item.route != null,
                  onTap: item.route == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          if (item.route == AppRoutes.dashboard) {
                            context.go(item.route!);
                          } else {
                            context.push(item.route!);
                          }
                        },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final String? route;

  const _MenuItem(this.label, this.icon, [this.route]);
}
