class SuperOwnerAccountSummary {
  final int owners;
  final int users;
  final int activeAccounts;
  final int inactiveAccounts;

  const SuperOwnerAccountSummary({
    required this.owners,
    required this.users,
    required this.activeAccounts,
    required this.inactiveAccounts,
  });

  factory SuperOwnerAccountSummary.fromJson(Map<String, dynamic> json) {
    int integer(String key) => (json[key] as num?)?.toInt() ?? 0;
    return SuperOwnerAccountSummary(
      owners: integer('owners'),
      users: integer('users'),
      activeAccounts: integer('active_accounts'),
      inactiveAccounts: integer('inactive_accounts'),
    );
  }
}

class OwnerAccountGroup {
  final String id;
  final String name;
  final String username;
  final bool isActive;
  final int userCount;

  const OwnerAccountGroup({
    required this.id,
    required this.name,
    required this.username,
    required this.isActive,
    required this.userCount,
  });

  factory OwnerAccountGroup.fromJson(Map<String, dynamic> json) =>
      OwnerAccountGroup(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '-',
        username: json['username']?.toString() ?? '-',
        isActive: json['is_active'] == true || json['is_active'] == 1,
        userCount: (json['user_count'] as num?)?.toInt() ?? 0,
      );
}

class DashboardSuperOwnerResponse {
  final SuperOwnerAccountSummary summary;
  final List<OwnerAccountGroup> owners;

  const DashboardSuperOwnerResponse({
    required this.summary,
    required this.owners,
  });

  factory DashboardSuperOwnerResponse.fromJson(Map<String, dynamic> json) {
    final ownerRows = (json['owners'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => OwnerAccountGroup.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    return DashboardSuperOwnerResponse(
      summary: SuperOwnerAccountSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? const {}),
      ),
      owners: ownerRows,
    );
  }
}
