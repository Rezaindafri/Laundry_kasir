import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../transactions/presentation/screens/transactions_screen.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../widgets/dashboard_shell.dart';
import '../widgets/dashboard_stat_card.dart';

/// Dashboard Kasir sesuai spesifikasi:
/// Transaksi Hari Ini, Laundry Diproses, Laundry Selesai, Belum Diambil.
class KasirDashboardScreen extends StatelessWidget {
  final UserEntity user;

  const KasirDashboardScreen({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      user: user,
      title: 'Dashboard Kasir',
      body: RefreshIndicator(
        onRefresh: () async =>
            Future.delayed(const Duration(milliseconds: 600)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Halo, ${user.name.split(' ').first} 👋',
                style: Theme.of(context).textTheme.titleMedium,),
            const SizedBox(height: 4),
            const Text('Berikut ringkasan aktivitas laundry hari ini.'),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: const [
                DashboardStatCard(
                  label: 'Transaksi Hari Ini',
                  value: '12',
                  icon: Icons.receipt_long_outlined,
                ),
                DashboardStatCard(
                  label: 'Laundry Diproses',
                  value: '7',
                  icon: Icons.local_laundry_service_outlined,
                  color: AppColors.statusDicuci,
                ),
                DashboardStatCard(
                  label: 'Laundry Selesai',
                  value: '4',
                  icon: Icons.check_circle_outline,
                  color: AppColors.statusSelesai,
                ),
                DashboardStatCard(
                  label: 'Belum Diambil',
                  value: '3',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NewTransactionScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Transaksi Baru'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
