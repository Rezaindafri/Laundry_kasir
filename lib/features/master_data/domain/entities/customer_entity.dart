import 'package:equatable/equatable.dart';

class CustomerEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String? notes;

  const CustomerEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
  });

  CustomerEntity copyWith({
    String? name,
    String? phone,
    String? address,
    String? notes,
  }) =>
      CustomerEntity(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        notes: notes ?? this.notes,
      );

  @override
  List<Object?> get props => [id, name, phone, address, notes];
}
