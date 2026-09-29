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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.title),
        centerTitle: true,
      ),
      drawer: AppNavigationDrawer(user: user),
      body: body,
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

/// Kerangka tetap untuk seluruh halaman tab. Hanya konten rute di dalamnya
/// yang dianimasikan, sehingga bottom navigation tidak ikut bergeser.
class PersistentTabShell extends ConsumerWidget {
  final Widget child;

  const PersistentTabShell({required this.child, super.key});

  Future<void> _handleSystemBack(BuildContext context) async {
    if (GoRouter.of(context).state.matchedLocation != AppRoutes.dashboard) {
      context.go(AppRoutes.dashboard);
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
    if (shouldExit == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).valueOrNull;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack(context);
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar:
            user == null ? null : AppBottomNavigation(user: user),
      ),
    );
  }
}

/// Bottom navigation bersama untuk setiap halaman tab utama.
/// QR Scanner sengaja tetap dibuka sebagai halaman sementara tanpa navigation bar.
class AppBottomNavigation extends StatelessWidget {
  final UserEntity user;

  const AppBottomNavigation({required this.user, super.key});

  List<_BottomNavItem> get _items {
    switch (user.role) {
      case UserRole.kasir:
        return const [
          _BottomNavItem('Beranda', Icons.home_outlined, Icons.home_rounded,
              AppRoutes.dashboard),
          _BottomNavItem('Transaksi', Icons.receipt_long_outlined,
              Icons.receipt_long_rounded, AppRoutes.transactions),
          _BottomNavItem('Scan QR', Icons.qr_code_scanner_outlined,
              Icons.qr_code_scanner_rounded, AppRoutes.qrScanner),
          _BottomNavItem('Pelanggan', Icons.people_outline,
              Icons.people_rounded, AppRoutes.customers),
          _BottomNavItem('Setting', Icons.settings_outlined,
              Icons.settings_rounded, AppRoutes.settings),
        ];
      case UserRole.owner:
        return const [
          _BottomNavItem('Beranda', Icons.home_outlined, Icons.home_rounded,
              AppRoutes.dashboard),
          _BottomNavItem('Transaksi', Icons.receipt_long_outlined,
              Icons.receipt_long_rounded, AppRoutes.transactions),
          _BottomNavItem('Scan QR', Icons.qr_code_scanner_outlined,
              Icons.qr_code_scanner_rounded, AppRoutes.qrScanner),
          _BottomNavItem('Laporan', Icons.bar_chart_outlined,
              Icons.bar_chart_rounded, AppRoutes.reports),
          _BottomNavItem('Setting', Icons.settings_outlined,
              Icons.settings_rounded, AppRoutes.settings),
        ];
      case UserRole.superOwner:
        return const [
          _BottomNavItem('Beranda', Icons.home_outlined, Icons.home_rounded,
              AppRoutes.dashboard),
          _BottomNavItem('Akun', Icons.manage_accounts_outlined,
              Icons.manage_accounts_rounded, AppRoutes.users),
          _BottomNavItem('Setting', Icons.settings_outlined,
              Icons.settings_rounded, AppRoutes.settings),
        ];
    }
  }

  int _selectedIndex(BuildContext context) {
    final location = GoRouter.of(context).state.matchedLocation;
    final directIndex = _items.indexWhere((item) => item.route == location);
    return directIndex;
  }

  void _onTap(BuildContext context, String route) {
    if (GoRouter.of(context).state.matchedLocation == route) return;
    if (route == AppRoutes.qrScanner) {
      context.push(route);
    } else {
      final targetIndex = _items.indexWhere((item) => item.route == route);
      context.pushReplacement(
        route,
        extra: AppTabTransition(
          movesLeft: targetIndex > _selectedIndex(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    return SafeArea(
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
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = index == selectedIndex;
              return Expanded(
                child: item.route == AppRoutes.qrScanner
                    ? _QrNavigationItem(
                        item: item,
                        isSelected: isSelected,
                        onTap: () => _onTap(context, item.route),
                      )
                    : _NavigationItem(
                        item: item,
                        isSelected: isSelected,
                        onTap: () => _onTap(context, item.route),
                      ),
              );
            }),
          ),
        ),
      ),
    );
  }
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.secondary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                  size: 23,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
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

/// Drawer yang dipakai bersama oleh seluruh halaman utama dalam navigation.
class AppNavigationDrawer extends StatelessWidget {
  final UserEntity user;

  const AppNavigationDrawer({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    final role = user.role;
    final menuItems = role == UserRole.superOwner
        ? const <_MenuItem>[
            _MenuItem(
                'Struktur Akun', Icons.dashboard_outlined, AppRoutes.dashboard),
            _MenuItem(
                'Kelola Akun', Icons.manage_accounts_outlined, AppRoutes.users),
            _MenuItem(
                'Pengaturan', Icons.settings_outlined, AppRoutes.settings),
          ]
        : <_MenuItem>[
            const _MenuItem(
                'Dashboard', Icons.dashboard_outlined, AppRoutes.dashboard),
            const _MenuItem('Transaksi', Icons.point_of_sale_outlined,
                AppRoutes.transactions),
            const _MenuItem(
                'Pelanggan', Icons.people_outline, AppRoutes.customers),
            if (role.canManageServicePrice)
              const _MenuItem('Layanan Laundry',
                  Icons.local_laundry_service_outlined, AppRoutes.services),
            const _MenuItem(
                'Scan QR', Icons.qr_code_scanner_outlined, AppRoutes.qrScanner),
            const _MenuItem('Riwayat Transaksi', Icons.history_outlined,
                AppRoutes.transactions),
            if (role.canViewProfitReports)
              const _MenuItem(
                  'Laporan', Icons.bar_chart_outlined, AppRoutes.reports),
            if (role == UserRole.owner)
              const _MenuItem('Riwayat Audit', Icons.history_edu_outlined,
                  AppRoutes.auditLogs),
            if (role.canManageUsers)
              const _MenuItem('Manajemen User', Icons.manage_accounts_outlined,
                  AppRoutes.users),
            const _MenuItem(
                'Pengaturan', Icons.settings_outlined, AppRoutes.settings),
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
                      style: AppTextStyles.title
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name,
                            style: AppTextStyles.title, maxLines: 1),
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
                children: menuItems
                    .map((item) => ListTile(
                          leading:
                              Icon(item.icon, color: AppColors.textSecondary),
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
                        ))
                    .toList(),
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
