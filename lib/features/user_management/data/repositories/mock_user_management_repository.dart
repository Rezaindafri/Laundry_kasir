import 'package:uuid/uuid.dart';

import '../../../../core/utils/result.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/repositories/user_management_repository.dart';

class MockUserManagementRepository implements UserManagementRepository {
  final _uuid = const Uuid();
  final List<UserEntity> _users = [
    UserEntity(
        id: 'usr-001',
        name: 'Budi Santoso',
        username: 'superowner',
        role: UserRole.superOwner,
        isActive: true,
        createdAt: DateTime(2025, 1, 1),),
    UserEntity(
        id: 'usr-002',
        name: 'Siti Aminah',
        username: 'owner',
        role: UserRole.owner,
        isActive: true,
        createdAt: DateTime(2025, 2, 10),),
    UserEntity(
        id: 'usr-003',
        name: 'Andi Wijaya',
        username: 'kasir',
        role: UserRole.kasir,
        isActive: true,
        createdAt: DateTime(2025, 3, 5),),
  ];
  @override
  Future<Result<List<UserEntity>>> getUsers() async =>
      Success(List.unmodifiable(_users));
  @override
  Future<Result<UserEntity>> saveUser(UserEntity user) async {
    final item = user.id.isEmpty
        ? UserEntity(
            id: _uuid.v4(),
            name: user.name,
            username: user.username,
            role: user.role,
            isActive: user.isActive,
            createdAt: DateTime.now(),)
        : user;
    final index = _users.indexWhere((entry) => entry.id == item.id);
    if (index < 0) {
      _users.add(item);
    } else {
      _users[index] = item;
    }
    return Success(item);
  }
}
