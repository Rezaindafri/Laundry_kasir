import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';
import '../models/dashboard_owner_model.dart';
import '../models/dashboard_kasir_model.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource remoteDataSource;

  const DashboardRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<DashboardOwnerResponse>> getOwnerDashboard() async {
    try {
      final data = await remoteDataSource.getOwnerDashboard();
      return Success(data);
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<DashboardKasirResponse>> getKasirDashboard() async {
    try {
      final data = await remoteDataSource.getKasirDashboard();
      return Success(data);
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }
}
