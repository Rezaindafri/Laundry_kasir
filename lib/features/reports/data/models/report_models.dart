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

class PaymentReportItem {
  final String id;
  final String invoice;
  final String customerName;
  final int amount;
  final int transactionTotal;
  final String method;
  final DateTime? paidAt;
  final String source;
  final String? recorderName;
  final String? note;

  const PaymentReportItem({
    required this.id,
    required this.invoice,
    required this.customerName,
    required this.amount,
    required this.transactionTotal,
    required this.method,
    required this.paidAt,
    required this.source,
    required this.recorderName,
    this.note,
  });

  factory PaymentReportItem.fromJson(Map<String, dynamic> json) {
    final recorder = json['recorded_by'];
    return PaymentReportItem(
      id: json['payment_id']?.toString() ?? '',
      invoice: json['invoice']?.toString() ?? '-',
      customerName: json['customer_name']?.toString() ?? 'Pelanggan',
      amount: _asInt(json['payment_amount']),
      transactionTotal: _asInt(json['total']),
      method: json['payment_method']?.toString() ?? 'cash',
      paidAt: DateTime.tryParse(json['paid_at']?.toString() ?? ''),
      source: json['payment_source']?.toString() ?? 'payment',
      recorderName: recorder is Map ? recorder['name']?.toString() : null,
      note: json['payment_note']?.toString(),
    );
  }
}

class OutstandingReportItem {
  final String id;
  final String invoice;
  final String customerName;
  final int total;
  final int paid;
  final int outstanding;

  const OutstandingReportItem({
    required this.id,
    required this.invoice,
    required this.customerName,
    required this.total,
    required this.paid,
    required this.outstanding,
  });

  factory OutstandingReportItem.fromJson(Map<String, dynamic> json) =>
      OutstandingReportItem(
        id: json['id']?.toString() ?? '',
        invoice: json['invoice']?.toString() ?? '-',
        customerName: json['customer_name']?.toString() ?? 'Pelanggan',
        total: _asInt(json['total']),
        paid: _asInt(json['paid_amount']),
        outstanding: _asInt(json['outstanding_amount']),
      );
}

class ExpenseReportItem {
  final String id;
  final int amount;
  final String category;
  final String? description;
  final DateTime? occurredAt;
  final String? recorderName;

  const ExpenseReportItem({
    required this.id,
    required this.amount,
    required this.category,
    required this.description,
    required this.occurredAt,
    required this.recorderName,
  });

  factory ExpenseReportItem.fromJson(Map<String, dynamic> json) {
    final recorder = json['recorded_by'];
    return ExpenseReportItem(
      id: json['id']?.toString() ?? '',
      amount: _asInt(json['amount']),
      category: json['category']?.toString() ?? 'Lainnya',
      description: json['description']?.toString(),
      occurredAt: DateTime.tryParse(json['occurred_at']?.toString() ?? ''),
      recorderName: recorder is Map ? recorder['name']?.toString() : null,
    );
  }
}

class OwnerReportOverview {
  final DateTime startDate;
  final DateTime endDate;
  final int orderValue;
  final int paymentsReceived;
  final int outstandingAmount;
  final int orderCount;
  final int paymentCount;
  final int ordersReceived;
  final int completed;
  final int late;
  final int readyToPickup;
  final int inProgress;
  final List<PaymentReportItem> payments;
  final List<OutstandingReportItem> outstandingItems;
  final List<ServiceStatistic> services;
  final List<ReportAccount> accounts;
  final List<ReportChartPoint> chart;
  final int cashPayments;
  final int qrisPayments;
  final int transferPayments;
  final int expensesTotal;
  final int expenseCount;
  final int netCash;
  final List<ExpenseReportItem> expenses;

  const OwnerReportOverview({
    required this.startDate,
    required this.endDate,
    required this.orderValue,
    required this.paymentsReceived,
    required this.outstandingAmount,
    required this.orderCount,
    required this.paymentCount,
    required this.ordersReceived,
    required this.completed,
    required this.late,
    required this.readyToPickup,
    required this.inProgress,
    required this.payments,
    required this.outstandingItems,
    required this.services,
    required this.accounts,
    required this.chart,
    required this.cashPayments,
    required this.qrisPayments,
    required this.transferPayments,
    required this.expensesTotal,
    required this.expenseCount,
    required this.netCash,
    required this.expenses,
  });

  factory OwnerReportOverview.fromJson(Map<String, dynamic> json) {
    final period = _map(json['period']);
    final summary = _map(json['summary']);
    final operational = _map(json['operational']);
    final methods = _map(json['payment_methods']);
    return OwnerReportOverview(
      startDate: DateTime.tryParse(period['start_date']?.toString() ?? '') ??
          DateTime.now(),
      endDate: DateTime.tryParse(period['end_date']?.toString() ?? '') ??
          DateTime.now(),
      orderValue: _asInt(summary['order_value']),
      paymentsReceived: _asInt(summary['payments_received']),
      outstandingAmount: _asInt(summary['outstanding_amount']),
      orderCount: _asInt(summary['order_count']),
      paymentCount: _asInt(summary['payment_count']),
      ordersReceived: _asInt(operational['orders_received']),
      completed: _asInt(operational['completed']),
      late: _asInt(operational['late']),
      readyToPickup: _asInt(operational['ready_to_pickup']),
      inProgress: _asInt(operational['in_progress']),
      payments:
          _list(json['payments']).map(PaymentReportItem.fromJson).toList(),
      outstandingItems: _list(json['outstanding_items'])
          .map(OutstandingReportItem.fromJson)
          .toList(),
      services: _list(json['services']).map(ServiceStatistic.fromJson).toList(),
      accounts: _list(json['accounts']).map(ReportAccount.fromJson).toList(),
      chart: _list(json['chart']).map(ReportChartPoint.fromJson).toList(),
      cashPayments: _asInt(methods['cash']),
      qrisPayments: _asInt(methods['qris']),
      transferPayments: _asInt(methods['transfer']),
      expensesTotal: _asInt(summary['expenses_total']),
      expenseCount: _asInt(summary['expense_count']),
      netCash: _asInt(summary['net_cash']),
      expenses:
          _list(json['expenses']).map(ExpenseReportItem.fromJson).toList(),
    );
  }
}

class ReportAccount {
  final String id;
  final String name;
  final String username;
  final bool isActive;
  final bool isOwner;

  const ReportAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.isActive,
    required this.isOwner,
  });

  String get label {
    if (isOwner) return 'Me (Owner)';
    return isActive ? name : '$name (Nonaktif)';
  }

  factory ReportAccount.fromJson(Map<String, dynamic> json) => ReportAccount(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Kasir',
        username: json['username']?.toString() ?? '',
        isActive: json['is_active'] == true || json['is_active'] == 1,
        isOwner: json['is_owner'] == true || json['is_owner'] == 1,
      );
}

class ReportChartPoint {
  final String label;
  final int value;

  const ReportChartPoint({required this.label, required this.value});

  factory ReportChartPoint.fromJson(Map<String, dynamic> json) =>
      ReportChartPoint(
        label: json['label']?.toString() ?? '-',
        value: _asInt(json['value']),
      );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : const [];

int _asInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
