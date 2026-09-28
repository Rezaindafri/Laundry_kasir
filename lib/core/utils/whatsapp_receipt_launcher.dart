import 'package:flutter/services.dart';

import 'whatsapp_launcher.dart';

/// Opens WhatsApp's conversation for [phone] with [image] attached. This is
/// Android-only; the native side owns the temporary file and its URI grant.
abstract class WhatsAppReceiptLauncher {
  WhatsAppReceiptLauncher._();

  static const _channel = MethodChannel(
    'com.example.laundry_management_system/whatsapp_receipt',
  );

  static Future<bool> open({
    required String? phone,
    required Uint8List image,
    required String message,
    required String filename,
  }) async {
    final normalizedPhone = WhatsAppLauncher.normalizedPhone(phone);
    if (normalizedPhone == null) return false;
    try {
      return await _channel.invokeMethod<bool>('openReceiptChat', {
            'phone': normalizedPhone,
            'image': image,
            'message': message,
            'filename': filename,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
