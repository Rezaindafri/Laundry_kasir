import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// Model data (JSON <-> Dart) untuk User. Terpisah dari UserEntity
/// supaya perubahan kontrak API tidak merembet ke domain/UI layer.
@freezed
class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String id,
    required String name,
    required String username,
    required String role,
    @JsonKey(name: 'is_active') required bool isActive,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  UserEntity toEntity() => UserEntity(
        id: id,
        name: name,
        username: username,
        role: UserRole.fromString(role),
        isActive: isActive,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
      );

  factory UserModel.fromEntity(UserEntity entity) => UserModel(
        id: entity.id,
        name: entity.name,
        username: entity.username,
        role: entity.role.apiValue,
        isActive: entity.isActive,
        avatarUrl: entity.avatarUrl,
        createdAt: entity.createdAt,
      );
}
