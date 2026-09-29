class SuperOwnerAccountChange {
  final String action;
  final String actorName;
  final String? actorUsername;
  final String subjectName;
  final String? subjectUsername;
  final DateTime? createdAt;

  const SuperOwnerAccountChange({
    required this.action,
    required this.actorName,
    required this.actorUsername,
    required this.subjectName,
    required this.subjectUsername,
    required this.createdAt,
  });

  String get label => switch (action) {
        'user.created' => 'Akun dibuat',
        'user.updated' => 'Akun diperbarui',
        'user.status_toggled' => 'Status akun diubah',
        'user.deleted' => 'Akun dihapus',
        _ => 'Perubahan akun',
      };

  factory SuperOwnerAccountChange.fromJson(Map<String, dynamic> json) =>
      SuperOwnerAccountChange(
        action: json['action']?.toString() ?? '',
        actorName: json['actor_name']?.toString() ?? 'Sistem',
        actorUsername: json['actor_username']?.toString(),
        subjectName: json['subject_name']?.toString() ?? 'Akun',
        subjectUsername: json['subject_username']?.toString(),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

class SuperOwnerSettings {
  final String applicationName;
  final String apiStatus;
  final DateTime? serverTime;
  final int passwordMinLength;
  final List<SuperOwnerAccountChange> accountChanges;

  const SuperOwnerSettings({
    required this.applicationName,
    required this.apiStatus,
    required this.serverTime,
    required this.passwordMinLength,
    required this.accountChanges,
  });

  factory SuperOwnerSettings.fromJson(Map<String, dynamic> json) {
    final system = Map<String, dynamic>.from(json['system'] as Map? ?? {});
    final policy =
        Map<String, dynamic>.from(json['account_policy'] as Map? ?? {});
    final changes = (json['recent_account_changes'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => SuperOwnerAccountChange.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    return SuperOwnerSettings(
      applicationName: system['application_name']?.toString() ?? 'Laundry App',
      apiStatus: system['api_status']?.toString() ?? 'unknown',
      serverTime: DateTime.tryParse(system['server_time']?.toString() ?? ''),
      passwordMinLength:
          (policy['password_min_length'] as num?)?.toInt() ?? 6,
      accountChanges: changes,
    );
  }
}
