import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/result.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/repositories/mock_user_management_repository.dart';
import '../../domain/repositories/user_management_repository.dart';

final userManagementRepositoryProvider =
    Provider<UserManagementRepository>((ref) => MockUserManagementRepository());
final managedUsersProvider =
    AsyncNotifierProvider<ManagedUsersNotifier, List<UserEntity>>(
        ManagedUsersNotifier.new,);

class ManagedUsersNotifier extends AsyncNotifier<List<UserEntity>> {
  @override
  Future<List<UserEntity>> build() async {
    final result = await ref.read(userManagementRepositoryProvider).getUsers();
    return result.when(
        success: (data) => data, error: (failure) => throw failure,);
  }

  Future<Result<UserEntity>> saveUser(UserEntity user) async {
    final result =
        await ref.read(userManagementRepositoryProvider).saveUser(user);
    result.when(
        success: (item) {
          final users = <UserEntity>[...(state.valueOrNull ?? [])];
          final index = users.indexWhere((entry) => entry.id == item.id);
          if (index < 0) {
            users.add(item);
          } else {
            users[index] = item;
          }
          state = AsyncData(users);
        },
        error: (_) {},);
    return result;
  }
}
