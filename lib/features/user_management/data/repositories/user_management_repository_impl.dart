import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../datasources/user_management_remote_datasource.dart';

class UserManagementRepositoryImpl implements UserManagementRepository {
  final UserManagementRemoteDataSource remoteDataSource;

  const UserManagementRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<UserEntity>>> getUsers() async {
    try {
      final users = await remoteDataSource.getUsers();
      return Success(users.map((item) => item.toEntity()).toList());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<UserEntity>> saveUser(
    UserEntity user, {
    String? password,
  }) async {
    try {
      final saved = await remoteDataSource.saveUser(user, password: password);
      return Success(saved.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<UserEntity>> updateCredentials({
    required UserEntity user,
    required String managerUsername,
    required String managerPassword,
    required String name,
    required String username,
    String? password,
  }) async {
    try {
      final saved = await remoteDataSource.updateCredentials(
        user: user,
        managerUsername: managerUsername,
        managerPassword: managerPassword,
        name: name,
        username: username,
        password: password,
      );
      return Success(saved.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }

  @override
  Future<Result<UserEntity>> toggleUserStatus(String id) async {
    try {
      final updated = await remoteDataSource.toggleUserStatus(id);
      return Success(updated.toEntity());
    } on ServerException catch (error) {
      return Error(ServerFailure(error.message));
    } on UnauthorizedException catch (error) {
      return Error(UnauthorizedFailure(error.message));
    } catch (_) {
      return const Error(UnknownFailure());
    }
  }
}
