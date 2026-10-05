import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

import 'file_output.dart';

/// QR kodunu vektör SVG olarak üretir (logo desteklenmez).
abstract final class QrSvgExport {
  static String colorHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  static String buildSvg({
    required String data,
    required Color foreground,
    required Color background,
    int errorCorrectionLevel = QrErrorCorrectLevel.M,
    int pixelSize = 512,
  }) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: errorCorrectionLevel,
    );
    final qrImage = QrImage(qrCode);
    final modules = qrImage.moduleCount;
    const quiet = 4;
    final total = modules + quiet * 2;
    final fg = colorHex(foreground);
    final bg = colorHex(background);

    final sb = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 $total $total" width="$pixelSize" height="$pixelSize">',
      )
      ..writeln('<rect width="$total" height="$total" fill="$bg"/>');

    for (var row = 0; row < modules; row++) {
      for (var col = 0; col < modules; col++) {
        if (qrImage.isDark(row, col)) {
          sb.writeln(
            '<rect x="${col + quiet}" y="${row + quiet}" width="1" height="1" fill="$fg"/>',
          );
        }
      }
    }
    sb.writeln('</svg>');
    return sb.toString();
  }

  /// Masaüstünde kaydeder (yolu döndürür), mobil/web'de paylaşır.
  static Future<String?> shareSvg({
    required String data,
    required Color foreground,
    required Color background,
    int errorCorrectionLevel = QrErrorCorrectLevel.M,
  }) async {
    final svg = buildSvg(
      data: data,
      foreground: foreground,
      background: background,
      errorCorrectionLevel: errorCorrectionLevel,
    );
    return FileOutput.saveOrShare(
      bytes: utf8.encode(svg),
      fileName: 'qr_kod.svg',
      mimeType: 'image/svg+xml',
      text: 'QR kod (SVG)',
    );
  }
}
