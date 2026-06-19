import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Builds the merchant UPI payment QR from a VPA (UPI ID) instead of an
/// uploaded image. A static QR carries no amount, so any UPI app reads it and
/// the customer enters the amount while paying.
class UpiQrHelper {
  const UpiQrHelper._();

  /// UPI deep link, e.g. `upi://pay?pa=merchant@okhdfc&pn=My%20Store&cu=INR`.
  static String buildUpiUri(String upiId, {String? payee}) {
    final params = <String, String>{'pa': upiId.trim(), 'cu': 'INR'};
    final name = payee?.trim();
    if (name != null && name.isNotEmpty) params['pn'] = name;
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'upi://pay?$query';
  }

  /// Renders the UPI QR to a white-background PNG so it prints cleanly on
  /// receipts. Returns null when [upiId] is empty.
  static Future<Uint8List?> generateQrBytes(
    String upiId, {
    String? payee,
    double size = 512,
  }) async {
    if (upiId.trim().isEmpty) return null;

    final painter = QrPainter(
      data: buildUpiUri(upiId, payee: payee),
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square, color: Color(0xFF000000)),
      dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square, color: Color(0xFF000000)),
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    painter.paint(canvas, Size(size, size));

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
