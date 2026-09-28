class RevenueReport {
  final int revenue;
  final int transactionCount;

  const RevenueReport({
    required this.revenue,
    required this.transactionCount,
  });

  factory RevenueReport.fromJson(Map<String, dynamic> json) => RevenueReport(
        revenue: _asInt(json['revenue']),
        transactionCount: _asInt(json['transaction_count']),
      );
}

class ServiceStatistic {
  final String serviceName;
  final int count;

  const ServiceStatistic({required this.serviceName, required this.count});

  factory ServiceStatistic.fromJson(Map<String, dynamic> json) =>
      ServiceStatistic(
        serviceName: json['service_name']?.toString() ?? 'Layanan',
        count: _asInt(json['count']),
      );
}

class ReportStatistics {
  final int totalRevenue;
  final int totalTransactions;
  final int totalCustomers;
  final int inProgress;
  final int readyToPickup;
  final List<ServiceStatistic> services;

  const ReportStatistics({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.totalCustomers,
    required this.inProgress,
    required this.readyToPickup,
    required this.services,
  });

  factory ReportStatistics.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};
    final rawServices =
        json['services'] is List ? json['services'] as List : [];

    return ReportStatistics(
      totalRevenue: _asInt(summary['total_revenue']),
      totalTransactions: _asInt(summary['total_transactions']),
      totalCustomers: _asInt(summary['total_customers']),
      inProgress: _asInt(summary['in_progress']),
      readyToPickup: _asInt(summary['ready_to_pickup']),
      services: rawServices
          .whereType<Map>()
          .map(
            (item) =>
                ServiceStatistic.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class ReportsOverview {
  final RevenueReport today;
  final RevenueReport thisMonth;
  final ReportStatistics statistics;

  const ReportsOverview({
    required this.today,
    required this.thisMonth,
    required this.statistics,
  });
}

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
