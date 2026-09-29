import '../../../../core/utils/result.dart';
import '../../data/models/dashboard_owner_model.dart';
import '../../data/models/dashboard_kasir_model.dart';
import '../../data/models/dashboard_super_owner_model.dart';

abstract class DashboardRepository {
  Future<Result<DashboardOwnerResponse>> getOwnerDashboard({
    String period,
    String? cashierId,
  });
  Future<Result<DashboardKasirResponse>> getKasirDashboard();
  Future<Result<DashboardSuperOwnerResponse>> getSuperOwnerDashboard();
}
