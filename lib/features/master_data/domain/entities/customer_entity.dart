import 'package:equatable/equatable.dart';

enum CustomerGender {
  male,
  female;

  String get apiValue => name;
  String get label => this == CustomerGender.male ? 'Laki-laki' : 'Perempuan';

  static CustomerGender? fromApiValue(String? value) => switch (value) {
        'male' => CustomerGender.male,
        'female' => CustomerGender.female,
        _ => null,
      };
}

class CustomerEntity extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final CustomerGender? gender;
  final String? notes;

  const CustomerEntity({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.gender,
    this.notes,
  });

  CustomerEntity copyWith(
          {String? name,
          String? phone,
          String? address,
          CustomerGender? gender,
          String? notes}) =>
      CustomerEntity(
          id: id,
          name: name ?? this.name,
          phone: phone ?? this.phone,
          address: address ?? this.address,
          gender: gender ?? this.gender,
          notes: notes ?? this.notes);

  @override
  List<Object?> get props => [id, name, phone, address, gender, notes];
}
