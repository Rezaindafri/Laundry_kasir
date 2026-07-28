import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../widgets/dashboard_shell.dart';
import '../widgets/dashboard_stat_card.dart';

/// Dashboard Owner sesuai spesifikasi: Pendapatan Hari Ini/Bulan Ini,
/// Jumlah Transaksi, status laundry, dan Total Pelanggan.
class OwnerDashboardScreen extends StatelessWidget {
  final UserEntity user;

  const OwnerDashboardScreen({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      user: user,
      title: 'Dashboard Owner',
      body: RefreshIndicator(
        onRefresh: () async => Future.delayed(const Duration(milliseconds: 600)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pendapatan Hari Ini',
                        style: TextStyle(color: Colors.white70, fontSize: 13),),
                    const SizedBox(height: 6),
                    const Text('Rp1.250.000',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,),),
                    const SizedBox(height: 4),
                    Text('Pendapatan Bulan Ini: Rp28.400.000',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: const [
                DashboardStatCard(
                  label: 'Jumlah Transaksi',
                  value: '38',
                  icon: Icons.receipt_long_outlined,
                ),
                DashboardStatCard(
                  label: 'Total Pelanggan',
                  value: '156',
                  icon: Icons.people_outline,
                  color: AppColors.info,
                ),
                DashboardStatCard(
                  label: 'Laundry Diproses',
                  value: '19',
                  icon: Icons.local_laundry_service_outlined,
                  color: AppColors.statusDicuci,
                ),
                DashboardStatCard(
                  label: 'Belum Diambil',
                  value: '5',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
