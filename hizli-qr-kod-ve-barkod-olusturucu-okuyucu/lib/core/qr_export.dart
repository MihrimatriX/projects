import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'file_output.dart';

abstract final class QrExport {
  /// QR kenarındaki sessiz bölge (modül). Standart 4 modül ister.
  static const quietModules = 4;

  /// [size]×[size] PNG üretir. Modüller tam sayı piksele hizalanır ve
  /// etrafta sessiz bölge bırakılır.
  ///
  /// Önceden `QrPainter.toImageData` kullanılıyordu: modül boyutu yarım
  /// piksele yuvarlandığı için içerik görselden taşıp kenar modülleri
  /// kırpılıyor, sessiz bölge de olmuyordu; uzun içerikli kodlar okunamıyordu.
  static Future<Uint8List?> renderPng({
    required String data,
    required int size,
    required Color foreground,
    required Color background,
    required int errorCorrectionLevel,
    Uint8List? logoBytes,
    double logoScale = 0.2,
  }) async {
    final QrImage qr;
    try {
      qr = QrImage(
          QrCode.fromData(data: data, errorCorrectLevel: errorCorrectionLevel));
    } on InputTooLongException {
      return null;
    }
    final modules = qr.moduleCount;
    final total = modules + quietModules * 2;
    // Mümkünse tam sayı modül boyutu; çok küçük boyutta kesirliye düş.
    final whole = size ~/ total;
    final module = whole >= 1 ? whole.toDouble() : size / total;
    final origin = (size - module * modules) / 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
    canvas.drawRect(rect, Paint()..color = background);

    final fg = Paint()
      ..color = foreground
      ..isAntiAlias = false;
    final path = Path();
    for (var y = 0; y < modules; y++) {
      for (var x = 0; x < modules; x++) {
        if (qr.isDark(y, x)) {
          path.addRect(Rect.fromLTWH(
              origin + x * module, origin + y * module, module, module));
        }
      }
    }
    canvas.drawPath(path, fg);

    final logoImage = (logoBytes == null || logoBytes.isEmpty)
        ? null
        : await _decodeBytes(logoBytes);
    if (logoImage != null) {
      final logoSide = size * logoScale.clamp(0.08, 0.35);
      final pad = logoSide * 0.12;
      final logoRect = Rect.fromCenter(
        center: rect.center,
        width: logoSide + pad * 2,
        height: logoSide + pad * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(logoRect, const Radius.circular(8)),
        Paint()..color = background,
      );
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(
            0, 0, logoImage.width.toDouble(), logoImage.height.toDouble()),
        Rect.fromCenter(center: rect.center, width: logoSide, height: logoSide),
        Paint(),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return byteData?.buffer.asUint8List();
  }

  /// Logo görseli açılamazsa (bozuk dosya) logosuz devam edilir.
  static Future<ui.Image?> _decodeBytes(Uint8List data) async {
    try {
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  /// Masaüstünde kaydeder (yolu döndürür), mobil/web'de paylaşır.
  static Future<String?> sharePng({
    required String data,
    required int size,
    required Color foreground,
    required Color background,
    required int errorCorrectionLevel,
    Uint8List? logoBytes,
    double logoScale = 0.2,
  }) async {
    final bytes = await renderPng(
      data: data,
      size: size,
      foreground: foreground,
      background: background,
      errorCorrectionLevel: errorCorrectionLevel,
      logoBytes: logoBytes,
      logoScale: logoScale,
    );
    if (bytes == null) {
      throw const FormatException('İçerik QR kod kapasitesini aşıyor.');
    }
    return FileOutput.saveOrShare(
      bytes: bytes,
      fileName: 'qr_kod.png',
      mimeType: 'image/png',
      text: 'QR kod',
    );
  }

  /// Logo alanı QR alanının %25 üstündeyse okunabilirlik riski.
  static bool logoTooLarge(double logoScale) => logoScale > 0.25;
}
