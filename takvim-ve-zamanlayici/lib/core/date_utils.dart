import 'package:intl/intl.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime startOfWeek(DateTime d, {int firstWeekday = DateTime.monday}) {
  final day = dateOnly(d);
  var diff = day.weekday - firstWeekday;
  if (diff < 0) diff += 7;
  return day.subtract(Duration(days: diff));
}

DateTime endOfWeek(DateTime d, {int firstWeekday = DateTime.monday}) {
  return startOfWeek(d, firstWeekday: firstWeekday).add(const Duration(days: 6));
}

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime d) => isSameDay(d, DateTime.now());

List<DateTime> daysInMonthGrid(DateTime month) {
  final first = startOfMonth(month);
  final last = endOfMonth(month);
  final gridStart = startOfWeek(first);
  final gridEnd = endOfWeek(last);
  final days = <DateTime>[];
  var cursor = gridStart;
  while (!cursor.isAfter(gridEnd)) {
    days.add(cursor);
    // +24 saat değil, takvim günü: yaz saati bitişinde aynı gün iki kez çıkıyordu.
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return days;
}

String formatWeekRange(DateTime anchor) {
  final start = startOfWeek(anchor);
  final end = endOfWeek(anchor);
  final fmt = DateFormat('d MMM', 'tr_TR');
  if (start.month == end.month) {
    return '${start.day}–${end.day} ${DateFormat('MMMM y', 'tr_TR').format(start)}';
  }
  return '${fmt.format(start)} – ${fmt.format(end)} ${start.year}';
}

String weekdayShort(DateTime d) {
  return DateFormat('EEE', 'tr_TR').format(d);
}

String formatTime(DateTime d) => DateFormat('HH:mm').format(d);

String formatDurationMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h > 0) return '${h}s ${m.toString().padLeft(2, '0')}dk';
  return '$m dk';
}

/// Takvim günü ekler, saat korunur. `Duration(days: n)` 24 saat ekler; yaz saati
/// geçişinde gece yarısı 23:00'e ya da 01:00'e kayar.
DateTime addDays(DateTime d, int n) =>
    DateTime(d.year, d.month, d.day + n, d.hour, d.minute, d.second, d.millisecond);
