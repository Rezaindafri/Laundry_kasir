import '../../../../core/utils/result.dart';
import '../../data/models/dashboard_owner_model.dart';
import '../../data/models/dashboard_kasir_model.dart';

abstract class DashboardRepository {
  Future<Result<DashboardOwnerResponse>> getOwnerDashboard();
  Future<Result<DashboardKasirResponse>> getKasirDashboard();
}
