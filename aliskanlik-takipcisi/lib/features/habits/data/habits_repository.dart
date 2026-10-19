import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/date_utils.dart';
import '../../../core/streak_logic.dart';
import '../models/habit.dart';

class HabitsRepository {
  static const _key = 'habits_v2';
  static const _legacyKey = 'habits_v1';
  static const backupKeyPrefix = 'habits_v2_bozuk_';

  /// Kayıtlı alışkanlıkları okur ve [now] gününe göre doneToday/seri
  /// alanlarını completionDates'ten yeniden hesaplar. Böylece kaçırılan günler
  /// seriyi kırar; saat dilimi değişse bile "bugün" işareti tarihlerle tutarlı
  /// kalır.
  ///
  /// Kayıt bozuksa (elle düzenleme, yarım yazma) ham veri
  /// [backupKeyPrefix] ile başlayan bir anahtara yedeklenir; böylece sonraki
  /// kayıt eski veriyi sessizce ezmez.
  Future<List<Habit>> load({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);

    final raw = prefs.getString(_key);
    if (raw == null) return [];

    final List<Habit> habits;
    try {
      habits = decodeHabits(raw, strict: false);
    } on FormatException {
      await _backupCorrupt(prefs, raw);
      return [];
    }
    if (habits.length != _rawCount(raw)) {
      // Bazı kayıtlar okunamadı: kalanlarla devam et ama aslını sakla.
      await _backupCorrupt(prefs, raw);
    }

    final normalized = normalize(habits, now: now);
    if (!_sameJson(normalized, habits)) await save(normalized);
    return normalized;
  }

  /// doneToday ve streak alanlarını [now] gününe göre tarihlerden türetir.
  static List<Habit> normalize(List<Habit> habits, {DateTime? now}) {
    final today = AppDates.todayKey(now);
    return habits.map((h) {
      final dates = h.completionDates.where(AppDates.isValidKey).toSet().toList()..sort();
      final next = h.copyWith(completionDates: dates);
      return next.copyWith(
        doneToday: dates.contains(today),
        streak: StreakLogic.computeStreak(next, today: today),
      );
    }).toList();
  }

  /// JSON metnini alışkanlık listesine çevirir. [strict] true ise hatalı tek
  /// bir kayıt bile FormatException fırlatır (içe aktarma), false ise hatalı
  /// kayıtlar atlanır (açılışta okuma).
  static List<Habit> decodeHabits(String raw, {bool strict = true}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Geçerli bir JSON değil.');
    }
    if (decoded is! List) {
      throw const FormatException('JSON bir alışkanlık listesi ([...]) olmalı.');
    }
    final habits = <Habit>[];
    final ids = <String>{};
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      try {
        if (item is! Map<String, dynamic>) throw const FormatException('nesne değil');
        final habit = Habit.fromJson(item);
        if (habit.id.isEmpty || habit.title.trim().isEmpty) {
          throw const FormatException('id/başlık boş');
        }
        final badDate = habit.completionDates.where((d) => !AppDates.isValidKey(d));
        if (strict && badDate.isNotEmpty) {
          throw FormatException('geçersiz tarih "${badDate.first}"');
        }
        if (!ids.add(habit.id)) throw FormatException('tekrarlanan id "${habit.id}"');
        habits.add(habit);
      } catch (e) {
        if (strict) {
          final reason = e is FormatException ? e.message : 'alanlar hatalı';
          throw FormatException('${i + 1}. kayıt okunamadı: $reason.');
        }
      }
    }
    return habits;
  }

  int _rawCount(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.length : -1;
    } on FormatException {
      return -1;
    }
  }

  bool _sameJson(List<Habit> a, List<Habit> b) =>
      jsonEncode(a.map((h) => h.toJson()).toList()) ==
      jsonEncode(b.map((h) => h.toJson()).toList());

  Future<void> _backupCorrupt(SharedPreferences prefs, String raw) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString('$backupKeyPrefix$stamp', raw);
  }

  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    if (prefs.containsKey(_key)) return;
    final legacy = prefs.getString(_legacyKey);
    if (legacy == null) return;

    final List<Habit> habits;
    try {
      habits = (jsonDecode(legacy) as List<dynamic>).map((e) {
        final map = e as Map<String, dynamic>;
        final dates = <String>[];
        final last = map['lastCompletedDate'] as String?;
        if (last != null) dates.add(last);
        return Habit(
          id: map['id'] as String,
          title: map['title'] as String,
          doneToday: map['doneToday'] as bool? ?? false,
          streak: map['streak'] as int? ?? 0,
          lastCompletedDate: last,
          completionDates: dates,
        );
      }).toList();
    } catch (_) {
      // Eski kayıt okunamıyor: silmeden bırak, yeni sürüm boş başlasın.
      return;
    }

    await save(habits);
    await prefs.remove(_legacyKey);
  }

  Future<void> save(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = await prefs.setString(
      _key,
      jsonEncode(habits.map((h) => h.toJson()).toList()),
    );
    if (!ok) throw StateError('Alışkanlıklar kaydedilemedi.');
  }

  Future<String> exportJson(List<Habit> habits) async {
    return const JsonEncoder.withIndent('  ').convert(habits.map((h) => h.toJson()).toList());
  }

  String exportCsv(List<Habit> habits) {
    final buffer = StringBuffer('id,title,icon,frequency,streak,completion_dates\n');
    for (final h in habits) {
      final dates = h.completionDates.join(';');
      buffer.writeln(
        '"${_escape(h.id)}","${_escape(h.title)}","${_escape(h.icon)}",${h.frequency.name},${h.streak},"$dates"',
      );
    }
    return buffer.toString();
  }

  String _escape(String s) => s.replaceAll('"', '""');
}
