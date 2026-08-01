import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/customer_entity.dart';
import '../../domain/entities/laundry_service_entity.dart';
import '../../domain/repositories/master_data_repository.dart';
import '../datasources/customer_remote_datasource.dart';
import '../datasources/service_remote_datasource.dart';

class MasterDataRepositoryImpl implements MasterDataRepository {
  final CustomerRemoteDataSource customerRemoteDataSource;
  final ServiceRemoteDataSource serviceRemoteDataSource;

  const MasterDataRepositoryImpl(
      {required this.customerRemoteDataSource,
      required this.serviceRemoteDataSource});

  @override
  Future<Result<List<CustomerEntity>>> getCustomers() async {
    try {
      final data = await customerRemoteDataSource.getCustomers();
      return Success(data.map((item) => item.toEntity()).toList());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<CustomerEntity>> saveCustomer(CustomerEntity customer) async {
    try {
      final data = await customerRemoteDataSource.saveCustomer(customer);
      return Success(data.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> deleteCustomer(String id) async {
    try {
      await customerRemoteDataSource.deleteCustomer(id);
      return const Success(null);
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<List<LaundryServiceEntity>>> getServices() async {
    try {
      final data = await serviceRemoteDataSource.getServices();
      return Success(data.map((item) => item.toEntity()).toList());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<LaundryServiceEntity>> saveService(
      LaundryServiceEntity service) async {
    try {
      final data = await serviceRemoteDataSource.saveService(service);
      return Success(data.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> deleteService(String id) async {
    try {
      await serviceRemoteDataSource.deleteService(id);
      return const Success(null);
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }
}
