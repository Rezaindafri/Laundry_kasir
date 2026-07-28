import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class UserManagementRepository {
  Future<Result<List<UserEntity>>> getUsers();
  Future<Result<UserEntity>> saveUser(UserEntity user);
}
