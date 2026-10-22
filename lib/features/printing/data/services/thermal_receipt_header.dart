import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Only the compact QR/customer header is rasterized. The receipt body remains
/// printer text: small payloads and no new image dependency or screenshot.
Future<List<int>> buildThermalReceiptHeader({
  required String invoice,
  required String customerName,
  required String customerPhone,
  required int width,
}) async {
  final qrLimit = width == 384 ? 144.0 : 176.0;
  final validated = QrValidator.validate(
      data: invoice,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M);
  final qr = validated.qrCode;
  if (qr == null) throw StateError('Kode QR struk tidak valid.');
  // Whole printer dots per module prevent blurred/uneven QR edges.
  final moduleDots = (qrLimit / qr.moduleCount).floor();
  if (moduleDots < 1) throw StateError('Kode QR terlalu panjang untuk struk.');
  final qrSize = (moduleDots * qr.moduleCount).toDouble();
  final quiet = (moduleDots * 4).toDouble();
  final textX = qrSize + quiet * 2 + 10;
  final text = TextPainter(
    text: TextSpan(
      style: TextStyle(
          color: const Color(0xFF000000),
          fontSize: width == 384 ? 22 : 26,
          fontFamily: 'monospace',
          height: 1.2),
      children: [
        TextSpan(
            text: customerName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        if (customerPhone.trim().isNotEmpty)
          TextSpan(text: '\n${customerPhone.trim()}'),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - textX - 4);
  final height = math.max(qrSize + quiet * 2, text.height + 12).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF));
  canvas.save();
  canvas.translate(quiet, quiet);
  QrPainter.withQr(
          qr: qr,
          gapless: true,
          eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
          dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)))
      .paint(canvas, Size.square(qrSize));
  canvas.restore();
  text.paint(canvas, Offset(textX, (height - text.height) / 2));
  text.dispose();
  final picture = recorder.endRecording();
  late final ui.Image image;
  try {
    image = await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
  try {
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) throw StateError('Header struk gagal dibuat.');
    final rowBytes = (width + 7) ~/ 8;
    final pixels = List<int>.filled(rowBytes * height, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final luminance = rgba.getUint8(offset) * 299 +
            rgba.getUint8(offset + 1) * 587 +
            rgba.getUint8(offset + 2) * 114;
        if (luminance < 128000)
          pixels[y * rowBytes + x ~/ 8] |= 0x80 >> (x % 8);
      }
    }
    // ESC/POS GS v 0, normal-density raster. No leading/trailing paper feed.
    return [
      0x1d,
      0x76,
      0x30,
      0,
      rowBytes & 255,
      rowBytes >> 8,
      height & 255,
      height >> 8,
      ...pixels
    ];
  } finally {
    image.dispose();
  }
}
