/// Kumpulan validator reusable untuk Form/TextFormField di seluruh fitur.
abstract class Validators {
  Validators._();

  static String? required(String? value, {String field = 'Field ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nomor HP wajib diisi';
    final pattern = RegExp(r'^(\+62|62|0)8[1-9][0-9]{6,10}$');
    if (!pattern.hasMatch(value.trim())) {
      return 'Format nomor HP tidak valid';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String field = 'Nilai'}) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    final number = num.tryParse(value.replaceAll(',', '.'));
    if (number == null || number <= 0) {
      return '$field harus berupa angka lebih dari 0';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }
}
