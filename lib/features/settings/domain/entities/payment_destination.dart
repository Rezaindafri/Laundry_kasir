class PaymentDestination {
  const PaymentDestination(
      {required this.id,
      required this.kind,
      required this.name,
      this.bankName,
      this.accountHolder,
      this.accountNumber,
      this.isActive = true,
      this.hasQrisImage = false});
  final int id;
  final String kind;
  final String name;
  final String? bankName;
  final String? accountHolder;
  final String? accountNumber;
  final bool isActive;
  final bool hasQrisImage;

  factory PaymentDestination.fromJson(Map<String, dynamic> json) =>
      PaymentDestination(
          id: int.parse(json['id'].toString()),
          kind: json['kind'] as String,
          name: json['name'] as String,
          bankName: json['bank_name'] as String?,
          accountHolder: json['account_holder'] as String?,
          accountNumber: json['account_number'] as String?,
          isActive: json['is_active'] == true,
          hasQrisImage: json['has_qris_image'] == true);

  String get label => kind == 'transfer' ? '$name · $bankName' : '$name · QRIS';
}
