import 'package:intl/intl.dart';

/// Hafta başlangıcı Pazartesi (Türkiye).
DateTime startOfWeek(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final weekday = local.weekday;
  return local.subtract(Duration(days: weekday - DateTime.monday));
}

String weekKey(DateTime weekStart) =>
    DateFormat('yyyy-MM-dd').format(weekStart);

DateTime parseWeekKey(String key) => DateFormat('yyyy-MM-dd').parse(key);

List<DateTime> weekDays(DateTime weekStart) =>
    List.generate(7, (i) => weekStart.add(Duration(days: i)));

const dayLabelsTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String formatWeekRange(DateTime weekStart) {
  final end = weekStart.add(const Duration(days: 6));
  final fmt = DateFormat('d MMM', 'tr_TR');
  return '${fmt.format(weekStart)} – ${fmt.format(end)}';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
