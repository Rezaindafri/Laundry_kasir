import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Shell umum untuk semua dashboard (Super Owner / Owner / Kasir).
/// AppBar menampilkan nama & role user, drawer menu menyesuaikan
/// hak akses role (UserRole.canX getters). Konten body & menu
/// masih placeholder — modul Transaksi, Pelanggan, dll menyusul
/// sebagai fitur terpisah.
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
    );
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
}

class _AppDrawer extends StatelessWidget {
  final UserEntity user;

  const _AppDrawer({required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user.role;

    final menuItems = <_MenuItem>[
      const _MenuItem(
        'Dashboard',
        Icons.dashboard_outlined,
        AppRoutes.dashboard,
      ),
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
      const _MenuItem(
        'Pengaturan',
        Icons.settings_outlined,
        AppRoutes.settings,
      ),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
                        Text(
                          user.name,
                          style: AppTextStyles.title,
                          maxLines: 1,
                        ),
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
                    .map(
                      (item) => ListTile(
                        leading:
                            Icon(item.icon, color: AppColors.textSecondary),
                        title: Text(item.label, style: AppTextStyles.body),
                        onTap: () {
                          Navigator.of(context).pop();
                          if (item.route == AppRoutes.dashboard) {
                            context.go(item.route!);
                          } else if (item.route != null) {
                            context.push(item.route!);
                          }
                        },
                      ),
                    )
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
