import '../../../../core/utils/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// UseCase login. Diletakkan di domain layer agar business rule
/// (mis. validasi tambahan sebelum call repository) terpisah dari UI.
class LoginUseCase {
  final AuthRepository repository;

  const LoginUseCase(this.repository);

  Future<Result<UserEntity>> call({
    required String username,
    required String password,
    required bool rememberMe,
  }) {
    return repository.login(
      username: username,
      password: password,
      rememberMe: rememberMe,
    );
  }
}
