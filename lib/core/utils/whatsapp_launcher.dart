import 'package:url_launcher/url_launcher.dart';

abstract class WhatsAppLauncher {
  WhatsAppLauncher._();

  static Future<bool> open(String? phone, {String? message}) async {
    final normalized = _normalize(phone);
    if (normalized == null) return false;
    final uri = Uri.https(
      'wa.me',
      '/$normalized',
      message == null || message.trim().isEmpty ? null : {'text': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String? _normalize(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    var digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) digits = digits.substring(1);
    if (digits.startsWith('0')) digits = '62${digits.substring(1)}';
    if (digits.startsWith('8')) digits = '62$digits';
    return digits.length >= 10 ? digits : null;
  }
}