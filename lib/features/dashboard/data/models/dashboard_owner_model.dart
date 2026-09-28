class DashboardOwnerSummary {
  final int revenue;
  final int transactions;
  final int customers;
  final int processing;
  final int readyToPickup;
  final int todayRevenue;

  const DashboardOwnerSummary({
    required this.revenue,
    required this.transactions,
    required this.customers,
    required this.processing,
    required this.readyToPickup,
    required this.todayRevenue,
  });

  factory DashboardOwnerSummary.fromJson(Map<String, dynamic> json) {
    return DashboardOwnerSummary(
      revenue: (json['revenue'] as num?)?.toInt() ?? 0,
      transactions: (json['transactions'] as num?)?.toInt() ??
          (json['transaction_count'] as num?)?.toInt() ??
          0,
      customers: (json['customers'] as num?)?.toInt() ??
          (json['customer_count'] as num?)?.toInt() ??
          0,
      processing: (json['processing'] as num?)?.toInt() ??
          (json['processing_count'] as num?)?.toInt() ??
          0,
      readyToPickup: (json['ready_to_pickup'] as num?)?.toInt() ??
          (json['readyToPickup'] as num?)?.toInt() ??
          0,
      todayRevenue: (json['today_revenue'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardChartPoint {
  final String label;
  final int value;

  const DashboardChartPoint({required this.label, required this.value});

  factory DashboardChartPoint.fromJson(Map<String, dynamic> json) {
    return DashboardChartPoint(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardOwnerResponse {
  final DashboardOwnerSummary summary;
  final List<DashboardChartPoint> chart;
  final List<String> accountOptions;
  final List<String> periodOptions;

  const DashboardOwnerResponse({
    required this.summary,
    required this.chart,
    required this.accountOptions,
    required this.periodOptions,
  });

  factory DashboardOwnerResponse.fromJson(Map<String, dynamic> json) {
    final chartJson = (json['chart'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final accountOptions = (json['account_options'] as List<dynamic>? ??
            (json['accountOptions'] as List<dynamic>? ?? const []))
        .map((item) => item.toString())
        .toList();

    final periodOptions = (json['period_options'] as List<dynamic>? ??
            (json['periodOptions'] as List<dynamic>? ?? const []))
        .map((item) => item.toString())
        .toList();

    return DashboardOwnerResponse(
      summary: DashboardOwnerSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),
      chart: chartJson.map(DashboardChartPoint.fromJson).toList(),
      accountOptions: accountOptions.isEmpty ? const ['Keseluruhan', 'Kasir 1'] : accountOptions,
      periodOptions: periodOptions.isEmpty ? const ['Minggu ini', 'Bulan ini', 'Tahun'] : periodOptions,
    );
  }
}
