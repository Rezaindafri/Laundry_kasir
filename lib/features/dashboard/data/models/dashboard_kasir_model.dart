import '../../../transactions/data/models/transaction_model.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class DashboardKasirSummary {
  final int transactionsToday;
  final int inProgress;
  final int completed;
  final int late;
  final int readyToPickup;
  final int dueSoon;

  const DashboardKasirSummary({
    required this.transactionsToday,
    required this.inProgress,
    required this.completed,
    required this.late,
    required this.readyToPickup,
    required this.dueSoon,
  });

  factory DashboardKasirSummary.fromJson(Map<String, dynamic> json) =>
      DashboardKasirSummary(
        transactionsToday: (json['transactions_today'] as num?)?.toInt() ?? 0,
        inProgress: (json['in_progress'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as num?)?.toInt() ?? 0,
        late: (json['late'] as num?)?.toInt() ?? 0,
        readyToPickup: (json['ready_to_pickup'] as num?)?.toInt() ?? 0,
        dueSoon: (json['due_soon'] as num?)?.toInt() ?? 0,
      );
}

class DashboardKasirResponse {
  final DashboardKasirSummary summary;
  final List<TransactionEntity> dueSoonItems;
  final List<TransactionEntity> readyToPickupItems;

  const DashboardKasirResponse({
    required this.summary,
    required this.dueSoonItems,
    required this.readyToPickupItems,
  });

  factory DashboardKasirResponse.fromJson(Map<String, dynamic> json) {
    List<TransactionEntity> parseItems(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((item) => TransactionModel.fromJson(
                  Map<String, dynamic>.from(item),
                ).toEntity())
            .toList();

    return DashboardKasirResponse(
      summary: DashboardKasirSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),
      dueSoonItems: parseItems('due_soon_items'),
      readyToPickupItems: parseItems('ready_to_pickup_items'),
    );
  }
}
