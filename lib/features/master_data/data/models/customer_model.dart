import '../../domain/entities/customer_entity.dart';

class CustomerModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final CustomerGender? gender;
  final int transactionsCount;

  const CustomerModel(
      {required this.id,
      required this.name,
      this.phone,
      this.address,
      this.gender,
      this.transactionsCount = 0});

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString(),
        address: json['address']?.toString(),
        gender: CustomerGender.fromApiValue(json['gender']?.toString()),
        transactionsCount: int.tryParse(
              json['transactions_count']?.toString() ??
                  json['transactionsCount']?.toString() ??
                  '0',
            ) ??
            0,
      );

  CustomerEntity toEntity() => CustomerEntity(
      id: id,
      name: name,
      phone: phone,
      address: address,
      gender: gender,
      notes: transactionsCount > 0 ? '$transactionsCount transaksi' : null);

  static Map<String, dynamic> toRequest(CustomerEntity entity) => {
        'name': entity.name,
        'phone':
            entity.phone?.trim().isEmpty ?? true ? null : entity.phone?.trim(),
        'address': entity.address?.trim().isEmpty ?? true
            ? null
            : entity.address?.trim(),
        'gender': entity.gender?.apiValue,
      };
}
