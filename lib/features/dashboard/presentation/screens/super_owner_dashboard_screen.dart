import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/dashboard_shell.dart';

class SuperOwnerDashboardScreen extends ConsumerWidget {
  final UserEntity user;

  const SuperOwnerDashboardScreen({required this.user, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(superOwnerDashboardProvider);

    return DashboardShell(
      user: user,
      title: 'Struktur Akun',
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(superOwnerDashboardProvider.notifier).refresh(),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 160),
              Text(
                'Gagal memuat struktur akun: $error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.read(superOwnerDashboardProvider.notifier).refresh(),
                child: const Text('Coba lagi'),
              ),
            ],
          ),
          data: (dashboard) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Pengelolaan akun',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kelola owner dan user tanpa memantau transaksi atau kinerja operasional.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SummaryCard(
                    label: 'Owner',
                    value: dashboard.summary.owners.toString(),
                    icon: Icons.business_outlined,
                  ),
                  _SummaryCard(
                    label: 'User',
                    value: dashboard.summary.users.toString(),
                    icon: Icons.people_outline,
                  ),
                  _SummaryCard(
                    label: 'Akun aktif',
                    value: dashboard.summary.activeAccounts.toString(),
                    icon: Icons.verified_user_outlined,
                  ),
                  _SummaryCard(
                    label: 'Akun nonaktif',
                    value: dashboard.summary.inactiveAccounts.toString(),
                    icon: Icons.person_off_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        '${AppRoutes.users}?create=owner',
                      ),
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Tambah Owner'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '${AppRoutes.users}?create=kasir',
                      ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Tambah User'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Owner dan user di bawahnya',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.users),
                    child: const Text('Kelola'),
                  ),
                ],
              ),
              if (dashboard.owners.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Belum ada akun Owner.'),
                  ),
                )
              else
                ...dashboard.owners.map(
                  (owner) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: owner.isActive
                            ? AppColors.secondary
                            : Colors.grey.shade300,
                        child: Icon(
                          Icons.business_outlined,
                          color: owner.isActive
                              ? AppColors.primary
                              : Colors.grey.shade700,
                        ),
                      ),
                      title: Text(owner.name),
                      subtitle: Text(
                        '@${owner.username} • ${owner.userCount} user • '
                        '${owner.isActive ? 'Aktif' : 'Nonaktif'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.users),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 42) / 2,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          )),
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
