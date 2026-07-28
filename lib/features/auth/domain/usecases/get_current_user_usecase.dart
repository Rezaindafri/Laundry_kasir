import '../../../../core/utils/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Dipakai saat Splash Screen untuk cek Auto Login / Remember Login.
class GetCurrentUserUseCase {
  final AuthRepository repository;

  const GetCurrentUserUseCase(this.repository);

  Future<Result<UserEntity?>> call() => repository.getCurrentUser();
}
