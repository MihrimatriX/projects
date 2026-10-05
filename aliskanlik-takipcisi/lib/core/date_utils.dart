import 'package:intl/intl.dart';

abstract final class AppDates {
  static String todayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return _key(d);
  }

  static String yesterdayKey([DateTime? date]) {
    return _key(daysBefore(date ?? DateTime.now(), 1));
  }

  // Gün çıkarma takvim üzerinden yapılır; Duration ile 24 saat çıkarmak
  // yaz saati geçişlerinde bir günü atlayabilir veya tekrarlayabilir.
  // Sonuç UTC gece yarısıdır: yalnızca takvim alanları (yıl/ay/gün/haftanın
  // günü) kullanılır, UTC'de yaz saati olmadığı için gün hep 24 saattir ve
  // Windows'ta yavaş olan yerel saat dilimi sorgusundan kaçınılır.
  static DateTime daysBefore(DateTime d, int n) => DateTime.utc(d.year, d.month, d.day - n);

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String weekKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    final monday = daysBefore(d, d.weekday - 1);
    return _key(monday);
  }

  static String previousWeekKey([DateTime? date]) {
    return weekKey(daysBefore(date ?? DateTime.now(), 7));
  }

  static String formatHeader(DateTime date) {
    return DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(date);
  }

  static String formatShort(DateTime date) {
    return DateFormat('d MMM', 'tr_TR').format(date);
  }

  static DateTime parseKey(String key) {
    final parts = key.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  static final _keyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// 'yyyy-MM-dd' biçiminde ve takvimde gerçekten var olan bir gün mü?
  /// (ör. 2025-02-29 geçersiz).
  static bool isValidKey(String key) {
    if (!_keyPattern.hasMatch(key)) return false;
    return _key(parseKey(key)) == key;
  }

  static List<String> lastNDays(int n, [DateTime? today]) {
    final ref = today ?? DateTime.now();
    return List.generate(n, (i) {
      final d = daysBefore(ref, n - 1 - i);
      return _key(d);
    });
  }
}
