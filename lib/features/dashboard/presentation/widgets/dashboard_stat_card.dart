import 'package:flutter/material.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_text_styles.dart';

/// Kartu statistik dashboard (mis. "Pendapatan Hari Ini", "Laundry Diproses").
/// Data masih dummy — akan disambungkan ke DashboardProvider saat
/// modul Transaksi & Laporan dibangun.
class DashboardStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool compact;

  const DashboardStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(compact ? 7 : 9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: compact ? 18 : 21),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text(value, style: AppTextStyles.headline)),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: onTap == null
                        ? Colors.transparent
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
              SizedBox(height: compact ? 1 : 3),
              Text(label, style: AppTextStyles.bodyMuted),
            ],
          ),
        ),
      ),
    );
  }
}
