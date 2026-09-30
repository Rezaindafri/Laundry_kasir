import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class UserManagementRepository {
  Future<Result<List<UserEntity>>> getUsers();
  Future<Result<UserEntity>> saveUser(UserEntity user, {String? password});
  Future<Result<UserEntity>> updateCredentials({
    required UserEntity user,
    required String managerUsername,
    required String managerPassword,
    required String name,
    required String username,
    String? password,
  });
  Future<Result<UserEntity>> toggleUserStatus(String id);
}
