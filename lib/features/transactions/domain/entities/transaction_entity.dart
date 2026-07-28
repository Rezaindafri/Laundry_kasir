import 'package:equatable/equatable.dart';

enum LaundryStatus { received, washing, drying, ironing, completed, collected }

enum PaymentMethod { cash, qris, transfer }

enum PaymentStatus { unpaid, downPayment, paid }

extension LaundryStatusLabel on LaundryStatus {
  String get label => switch (this) {
        LaundryStatus.received => 'Diterima',
        LaundryStatus.washing => 'Dicuci',
        LaundryStatus.drying => 'Dikeringkan',
        LaundryStatus.ironing => 'Disetrika',
        LaundryStatus.completed => 'Selesai',
        LaundryStatus.collected => 'Sudah Diambil',
      };
}

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Tunai',
        PaymentMethod.qris => 'QRIS',
        PaymentMethod.transfer => 'Transfer',
      };
}

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.unpaid => 'Belum Bayar',
        PaymentStatus.downPayment => 'DP',
        PaymentStatus.paid => 'Lunas',
      };
}

class TransactionEntity extends Equatable {
  final String id;
  final String invoice;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String serviceName;
  final double quantity;
  final String quantityUnit;
  final int unitPrice;
  final int expressFee;
  final int total;
  final int paidAmount;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final LaundryStatus laundryStatus;
  final DateTime createdAt;
  final DateTime estimatedFinishAt;
  final String? notes;

  const TransactionEntity({
    required this.id,
    required this.invoice,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.quantity,
    required this.quantityUnit,
    required this.unitPrice,
    required this.expressFee,
    required this.total,
    required this.paidAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.laundryStatus,
    required this.createdAt,
    required this.estimatedFinishAt,
    this.notes,
  });

  int get remainingPayment => total - paidAmount;

  TransactionEntity copyWith({
    int? paidAmount,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    LaundryStatus? laundryStatus,
  }) =>
      TransactionEntity(
        id: id,
        invoice: invoice,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        serviceName: serviceName,
        quantity: quantity,
        quantityUnit: quantityUnit,
        unitPrice: unitPrice,
        expressFee: expressFee,
        total: total,
        paidAmount: paidAmount ?? this.paidAmount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        laundryStatus: laundryStatus ?? this.laundryStatus,
        createdAt: createdAt,
        estimatedFinishAt: estimatedFinishAt,
        notes: notes,
      );

  @override
  List<Object?> get props => [
        id,
        invoice,
        customerId,
        total,
        paidAmount,
        paymentStatus,
        laundryStatus,
      ];
}
