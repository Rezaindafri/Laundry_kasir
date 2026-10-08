class DashboardOwnerSummary {
  final int revenue;
  final int transactions;
  final int customers;
  final int processing;
  final int readyToPickup;
  final int todayRevenue;
  final int orderValue;
  final int paymentsReceived;
  final int outstandingAmount;
  final int expensesTotal;
  final int expenseCount;

  const DashboardOwnerSummary({
    required this.revenue,
    required this.transactions,
    required this.customers,
    required this.processing,
    required this.readyToPickup,
    required this.todayRevenue,
    required this.orderValue,
    required this.paymentsReceived,
    required this.outstandingAmount,
    required this.expensesTotal,
    required this.expenseCount,
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
      orderValue: (json['order_value'] as num?)?.toInt() ?? 0,
      paymentsReceived: (json['payments_received'] as num?)?.toInt() ??
          (json['revenue'] as num?)?.toInt() ??
          0,
      outstandingAmount: (json['outstanding_amount'] as num?)?.toInt() ?? 0,
      expensesTotal: (json['expenses_total'] as num?)?.toInt() ?? 0,
      expenseCount: (json['expense_count'] as num?)?.toInt() ?? 0,
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

class DashboardOwnerAccount {
  final String id;
  final String name;
  final String username;
  final bool isActive;
  final bool isOwner;

  const DashboardOwnerAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.isActive,
    required this.isOwner,
  });

  String get label {
    if (isOwner) return 'Me (Owner)';
    final identity = username.isEmpty ? name : '$name (@$username)';
    return isActive ? identity : '$identity (Nonaktif)';
  }

  factory DashboardOwnerAccount.fromJson(Map<String, dynamic> json) =>
      DashboardOwnerAccount(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '-',
        username: json['username']?.toString() ?? '',
        isActive: json['is_active'] == true || json['is_active'] == 1,
        isOwner: json['is_owner'] == true || json['is_owner'] == 1,
      );
}

class DashboardOwnerResponse {
  final DashboardOwnerSummary summary;
  final List<DashboardChartPoint> chart;
  final List<DashboardOwnerAccount> accounts;
  final Map<String, dynamic> insights;
  final List<Map<String, dynamic>> paymentDetails;
  final List<Map<String, dynamic>> outstandingItems;
  final List<Map<String, dynamic>> expenseDetails;

  const DashboardOwnerResponse({
    required this.summary,
    required this.chart,
    required this.accounts,
    required this.insights,
    required this.paymentDetails,
    required this.outstandingItems,
    required this.expenseDetails,
  });

  factory DashboardOwnerResponse.fromJson(Map<String, dynamic> json) {
    final chartJson = (json['chart'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final accounts = (json['accounts'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => DashboardOwnerAccount.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();

    return DashboardOwnerResponse(
      summary: DashboardOwnerSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map? ?? {}),
      ),
      chart: chartJson.map(DashboardChartPoint.fromJson).toList(),
      accounts: accounts,
      insights: Map<String, dynamic>.from(json['insights'] as Map? ?? {}),
      paymentDetails: _objectList(json['payment_details']),
      outstandingItems: _objectList(json['outstanding_items']),
      expenseDetails: _objectList(json['expense_details']),
    );
  }
}

class OwnerFinancialSnapshot {
  final String period;
  final int paymentsReceived;
  final int paymentCount;
  final List<DashboardChartPoint> chart;
  final List<Map<String, dynamic>> paymentDetails;

  const OwnerFinancialSnapshot({
    required this.period,
    required this.paymentsReceived,
    required this.paymentCount,
    required this.chart,
    required this.paymentDetails,
  });

  factory OwnerFinancialSnapshot.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map? ?? {});
    final chart = (json['chart'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => DashboardChartPoint.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList();
    return OwnerFinancialSnapshot(
      period: json['period']?.toString() ?? 'week',
      paymentsReceived: (summary['payments_received'] as num?)?.toInt() ?? 0,
      paymentCount: (summary['payment_count'] as num?)?.toInt() ?? 0,
      chart: chart,
      paymentDetails: _objectList(json['payment_details']),
    );
  }
}

List<Map<String, dynamic>> _objectList(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : const [];
