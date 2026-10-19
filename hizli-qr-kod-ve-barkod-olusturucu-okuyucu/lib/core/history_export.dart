import 'dart:convert';

import 'file_output.dart';

abstract final class HistoryExport {
  /// Masaüstünde kaydeder (yolu döndürür), mobil/web'de paylaşır.
  static Future<String?> shareJson({
    required String title,
    required List<String> created,
    required List<String> scanned,
  }) async {
    final payload = jsonEncode({
      'exportedAt': DateTime.now().toIso8601String(),
      'created': created,
      'scanned': scanned,
    });
    return FileOutput.saveOrShare(
      bytes: utf8.encode(payload),
      fileName: 'qr_gecmis.json',
      mimeType: 'application/json',
      text: title,
    );
  }
}
