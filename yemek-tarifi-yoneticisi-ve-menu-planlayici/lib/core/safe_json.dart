import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kayıtlı JSON'u [T] (List/Map) olarak çözer. Bozuk ya da beklenmeyen türdeyse ham
/// veri `<key>_bozuk_yedek` anahtarına kopyalanır ve null döner; böylece ekran hata
/// vermek yerine boş açılır, bir sonraki kayıt da eski veriyi geri dönüşsüz ezmez.
Future<T?> decodeStoredJson<T>(SharedPreferences prefs, String key, String raw) async {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is T) return decoded;
  } on FormatException {
    // aşağıda yedeklenir
  }
  await prefs.setString('${key}_bozuk_yedek', raw);
  return null;
}
