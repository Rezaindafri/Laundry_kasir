import 'package:equatable/equatable.dart';
import '../../../../shared/enums/user_role.dart';

/// Entity murni (tanpa dependency JSON) yang dipakai di domain &
/// presentation layer. Konversi dari/ke JSON ada di UserModel (data layer).
class UserEntity extends Equatable {
  final String id;
  final String name;
  final String username;
  final UserRole role;
  final String? ownerId;
  final bool isActive;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.ownerId,
    required this.isActive,
    required this.createdAt,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        username,
        role,
        ownerId,
        isActive,
        avatarUrl,
      ];
}
