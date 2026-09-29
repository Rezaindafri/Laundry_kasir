import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/result.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../data/datasources/user_management_remote_datasource.dart';
import '../../data/repositories/user_management_repository_impl.dart';
import '../../domain/repositories/user_management_repository.dart';

final userManagementRemoteDataSourceProvider =
    Provider<UserManagementRemoteDataSource>(
  (ref) => UserManagementRemoteDataSourceImpl(DioClient().dio),
);

final userManagementRepositoryProvider = Provider<UserManagementRepository>(
  (ref) => UserManagementRepositoryImpl(
    remoteDataSource: ref.watch(userManagementRemoteDataSourceProvider),
  ),
);
final managedUsersProvider =
    AsyncNotifierProvider<ManagedUsersNotifier, List<UserEntity>>(
  ManagedUsersNotifier.new,
);

class ManagedUsersNotifier extends AsyncNotifier<List<UserEntity>> {
  @override
  Future<List<UserEntity>> build() async {
    ref.watch(currentSessionUserIdProvider);
    final result = await ref.read(userManagementRepositoryProvider).getUsers();
    return result.when(
      success: (data) => data,
      error: (failure) => throw failure,
    );
  }

  Future<Result<UserEntity>> saveUser(
    UserEntity user, {
    String? password,
  }) async {
    final result = await ref
        .read(userManagementRepositoryProvider)
        .saveUser(user, password: password);
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
      error: (_) {},
    );
    return result;
  }

  Future<Result<UserEntity>> toggleUserStatus(String id) async {
    final result =
        await ref.read(userManagementRepositoryProvider).toggleUserStatus(id);
    result.when(
      success: (item) {
        final users = <UserEntity>[...(state.valueOrNull ?? [])];
        final index = users.indexWhere((entry) => entry.id == item.id);
        if (index >= 0) {
          users[index] = item;
          state = AsyncData(users);
        }
      },
      error: (_) {},
    );
    return result;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}
