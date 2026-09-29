/// 3 role pengguna sesuai spesifikasi bisnis.
enum UserRole {
  superOwner,
  owner,
  kasir;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'super_owner':
      case 'superowner':
        return UserRole.superOwner;
      case 'owner':
        return UserRole.owner;
      case 'kasir':
        return UserRole.kasir;
      default:
        throw ArgumentError('Role tidak dikenal: $value');
    }
  }

  String get apiValue {
    switch (this) {
      case UserRole.superOwner:
        return 'super_owner';
      case UserRole.owner:
        return 'owner';
      case UserRole.kasir:
        return 'kasir';
    }
  }

  String get label {
    switch (this) {
      case UserRole.superOwner:
        return 'Super Owner';
      case UserRole.owner:
        return 'Owner';
      case UserRole.kasir:
        return 'Kasir';
    }
  }

  bool get isOwnerOrAbove =>
      this == UserRole.owner || this == UserRole.superOwner;

  bool get canManageUsers => isOwnerOrAbove;
  bool get canViewProfitReports => this == UserRole.owner;
  bool get canManageServicePrice => this == UserRole.owner;
  bool get canDeleteTransaction => this == UserRole.owner;
  bool get canBackupRestore => this == UserRole.superOwner;
  bool get canDeleteAccount => this == UserRole.superOwner;
}
