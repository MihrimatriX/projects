import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/palette_core.dart';

class PaletteHistoryEntry {
  const PaletteHistoryEntry({required this.colors, required this.date});

  final List<String> colors;
  final DateTime date;

  Map<String, dynamic> toJson() => {
        'colors': colors,
        'date': date.toIso8601String(),
      };

  factory PaletteHistoryEntry.fromJson(Map<String, dynamic> json) => PaletteHistoryEntry(
        colors: (json['colors'] as List<dynamic>).cast<String>(),
        date: DateTime.parse(json['date'] as String),
      );
}

class PaletteHistoryRepository {
  static const _key = 'palet:history';
  static const maxItems = 20;

  Future<List<PaletteHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    // Bozuk kayıt uygulamayı/geçmişi kilitlemesin: okunamayan veya geçersiz
    // HEX içeren girdiler atlanır.
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    if (decoded is! List) return [];
    final out = <PaletteHistoryEntry>[];
    for (final e in decoded) {
      try {
        final entry = PaletteHistoryEntry.fromJson(e as Map<String, dynamic>);
        final colors = entry.colors.map(PaletteCore.normalizeHex).toList();
        if (colors.isEmpty || colors.contains(null)) continue;
        out.add(PaletteHistoryEntry(colors: colors.cast<String>(), date: entry.date));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<void> add(List<String> colors, {bool force = false}) async {
    final list = await load();
    final sig = colors.join('|');
    if (!force && list.isNotEmpty && list.first.colors.join('|') == sig) return;

    list.insert(0, PaletteHistoryEntry(colors: colors, date: DateTime.now()));
    while (list.length > maxItems) {
      list.removeLast();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
