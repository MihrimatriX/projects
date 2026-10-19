import 'date_utils.dart';

/// Basit Türkçe doğal dil girişi: "Yarın 15:00 toplantı", "Bugün 10:30 doktor"
class ParsedEventDraft {
  const ParsedEventDraft({
    required this.title,
    required this.start,
    this.duration = const Duration(hours: 1),
  });

  final String title;
  final DateTime start;
  final Duration duration;

  DateTime get end => start.add(duration);
}

ParsedEventDraft? parseNaturalLanguageEvent(String input, {DateTime? reference}) {
  final ref = reference ?? DateTime.now();
  var text = input.trim();
  if (text.isEmpty) return null;

  final timeMatch = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(text);
  int hour = ref.hour + 1;
  int minute = 0;
  if (timeMatch != null) {
    hour = int.parse(timeMatch.group(1)!);
    minute = int.parse(timeMatch.group(2)!);
    text = text.replaceRange(timeMatch.start, timeMatch.end, '').trim();
  }

  var date = DateTime(ref.year, ref.month, ref.day);

  final lower = text.toLowerCase();
  if (lower.contains('bugün') || lower.contains('bugun')) {
    text = text.replaceAll(RegExp(r'bugün|bugun', caseSensitive: false), '').trim();
  } else if (lower.contains('yarın') || lower.contains('yarin')) {
    date = addDays(date, 1);
    text = text.replaceAll(RegExp(r'yarın|yarin', caseSensitive: false), '').trim();
  } else if (lower.contains('öbür gün') || lower.contains('obur gun')) {
    date = addDays(date, 2);
    text = text.replaceAll(RegExp(r'öbür gün|obur gun', caseSensitive: false), '').trim();
  } else {
    final weekday = _parseWeekday(lower);
    if (weekday != null) {
      date = _nextWeekday(date, weekday);
      text = text.replaceAll(_weekdayPattern, '').trim();
    } else {
      final dateMatch = RegExp(
              r'(\d{1,2})\s*(ocak|şubat|subat|mart|nisan|mayıs|mayis|haziran|temmuz|ağustos|agustos|eylül|eylul|ekim|kasım|kasim|aralık|aralik)(?:\s*(\d{4}))?',
              caseSensitive: false)
          .firstMatch(lower);
      if (dateMatch != null) {
        final day = int.parse(dateMatch.group(1)!);
        final month = _monthFromName(dateMatch.group(2)!);
        final year = dateMatch.group(3) != null ? int.parse(dateMatch.group(3)!) : ref.year;
        date = DateTime(year, month, day);
        text = text.replaceRange(dateMatch.start, dateMatch.end, '').trim();
      }
    }
  }

  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'^[-–—]\s*'), '').trim();
  if (text.isEmpty) text = 'Etkinlik';

  final start = DateTime(date.year, date.month, date.day, hour, minute);
  return ParsedEventDraft(title: _capitalizeTitle(text), start: start);
}

// Sıra önemli: "cumartesi" içinde "cuma", "pazartesi" içinde "pazar" geçer;
// uzun adlar önce denenmeli.
int? _parseWeekday(String lower) {
  const map = {
    'cumartesi': DateTime.saturday,
    'pazartesi': DateTime.monday,
    'salı': DateTime.tuesday,
    'sali': DateTime.tuesday,
    'çarşamba': DateTime.wednesday,
    'carsamba': DateTime.wednesday,
    'perşembe': DateTime.thursday,
    'persembe': DateTime.thursday,
    'cuma': DateTime.friday,
    'pazar': DateTime.sunday,
  };
  for (final entry in map.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

final _weekdayPattern = RegExp(
  r'pazartesi|salı|sali|çarşamba|carsamba|perşembe|persembe|cumartesi|cuma|pazar',
  caseSensitive: false,
);

DateTime _nextWeekday(DateTime from, int weekday) {
  var d = from;
  while (d.weekday != weekday || d.isBefore(from)) {
    d = addDays(d, 1);
    if (d.difference(from).inDays > 7) break;
  }
  if (d.isBefore(from)) d = addDays(d, 7);
  return DateTime(d.year, d.month, d.day);
}

int _monthFromName(String name) {
  final n = name
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
  const months = {
    'ocak': 1,
    'subat': 2,
    'mart': 3,
    'nisan': 4,
    'mayis': 5,
    'haziran': 6,
    'temmuz': 7,
    'agustos': 8,
    'eylul': 9,
    'ekim': 10,
    'kasim': 11,
    'aralik': 12,
  };
  return months[n] ?? 1;
}

String _capitalizeTitle(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
