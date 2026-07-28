import 'package:flutter/material.dart';

import '../../../auth/domain/entities/user_entity.dart';
import 'owner_dashboard_screen.dart';

/// Super Owner memiliki visibilitas sama seperti Owner (semua laporan &
/// transaksi) ditambah kemampuan manajemen user & backup/restore yang
/// sudah otomatis muncul di drawer (lihat DashboardShell -> _AppDrawer)
/// karena UserRole.canBackupRestore hanya true untuk Super Owner.
class SuperOwnerDashboardScreen extends StatelessWidget {
  final UserEntity user;

  const SuperOwnerDashboardScreen({required this.user, super.key});

  @override
  Widget build(BuildContext context) {
    return OwnerDashboardScreen(user: user);
  }
}
