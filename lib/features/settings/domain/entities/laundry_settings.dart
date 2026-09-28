class LaundrySettings {
  final String businessName;
  final String phone;
  final String address;
  final String paperSize;
  final String? defaultPrinter;
  final String? defaultPrinterName;
  const LaundrySettings({
    required this.businessName,
    required this.phone,
    required this.address,
    required this.paperSize,
    this.defaultPrinter,
    this.defaultPrinterName,
  });
  LaundrySettings copyWith({
    String? businessName,
    String? phone,
    String? address,
    String? paperSize,
    String? defaultPrinter,
    String? defaultPrinterName,
  }) =>
      LaundrySettings(
        businessName: businessName ?? this.businessName,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        paperSize: paperSize ?? this.paperSize,
        defaultPrinter: defaultPrinter ?? this.defaultPrinter,
        defaultPrinterName: defaultPrinterName ?? this.defaultPrinterName,
      );
}
