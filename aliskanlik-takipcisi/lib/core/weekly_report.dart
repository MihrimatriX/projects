import 'package:intl/intl.dart';

import '../features/habits/models/habit.dart';
import 'date_utils.dart';
import 'streak_logic.dart';

abstract final class WeeklyReport {
  static String generate(List<Habit> habits, {DateTime? now}) {
    if (habits.isEmpty) return 'Henüz alışkanlık yok.';

    final ref = now ?? DateTime.now();
    // Takvim aritmetiği: yaz saati geçişinde Duration çıkarmak günü kaydırabilir.
    final weekStart = AppDates.daysBefore(ref, ref.weekday - 1);
    final weekEnd = AppDates.daysBefore(weekStart, -6);
    final fmt = DateFormat('d MMM', 'tr_TR');
    final header =
        'Haftalık Alışkanlık Raporu\n${fmt.format(weekStart)} – ${fmt.format(weekEnd)}\n';

    final buffer = StringBuffer(header);
    buffer.writeln('${'=' * 32}\n');

    var totalCheckins = 0;
    for (final h in habits) {
      final weekCount = StreakLogic.weekCompletionCount(h.completionDates, AppDates.weekKey(ref));
      totalCheckins += weekCount;

      final flex = h.flexStreakEnabled ? ' (esnek ${h.flexTargetPerWeek}/7)' : '';
      buffer.writeln('${h.icon} ${h.title}$flex');
      buffer.writeln('  Bu hafta: $weekCount · Seri: ${h.streak} gün/hafta');
      if (h.doneToday) buffer.writeln('  ✓ Bugün tamamlandı');
      buffer.writeln();
    }

    buffer.writeln('Toplam check-in: $totalCheckins');
    buffer.writeln('En uzun seri: ${_bestStreak(habits)}');
    buffer.writeln('\n— Alışkanlık Takipçisi');

    return buffer.toString();
  }

  static int _bestStreak(List<Habit> habits) {
    if (habits.isEmpty) return 0;
    return habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);
  }
}
