import '../features/habits/models/habit.dart';
import 'date_utils.dart';

abstract final class StreakLogic {
  // Seri her zaman completionDates ('yyyy-MM-dd' yerel takvim anahtarları)
  // üzerinden yeniden hesaplanır: günlükte bugünden/dünden geriye ardışık gün,
  // haftalıkta ardışık hafta, esnek modda hedefi tutturan ardışık hafta sayılır.
  //
  // Tüm hesaplar [today] anahtarından türetilir; içeride DateTime.now()
  // kullanılmaz. Gün aritmetiği takvim üzerinden yapıldığı için yaz saati
  // geçişleri (23/25 saatlik günler) seriyi bozmaz. Saat dilimi değişip
  // "bugün"ün gerisinde kalan (gelecek tarihli) kayıtlar seriye katılmaz.
  static int computeStreak(Habit habit, {required String today, String? yesterday}) {
    final dates = _validDates(habit.completionDates, today);
    if (dates.isEmpty) return 0;

    final ref = AppDates.parseKey(today);
    if (habit.flexStreakEnabled && habit.frequency == HabitFrequency.daily) {
      return flexWeeklyStreak(dates, habit.flexTargetPerWeek, today: ref);
    }
    if (habit.frequency == HabitFrequency.weekly) {
      return _weeklyStreak(dates, ref);
    }
    return _dailyStreak(dates, ref);
  }

  /// [dates] içinde [weekKey] haftasına düşen farklı gün sayısı.
  static int weekCompletionCount(Iterable<String> dates, String weekKey) {
    return dates
        .toSet()
        .where((d) => AppDates.isValidKey(d) && AppDates.weekKey(AppDates.parseKey(d)) == weekKey)
        .length;
  }

  static int currentWeekProgress(Habit habit, {DateTime? today}) {
    return weekCompletionCount(habit.completionDates, AppDates.weekKey(today));
  }

  /// Hedefi ([target] gün/hafta) tutturan ardışık hafta sayısı. İçinde
  /// bulunulan hafta hedefe hâlâ ulaşabiliyorsa seri bozulmuş sayılmaz,
  /// yalnızca henüz sayılmaz.
  static int flexWeeklyStreak(Iterable<String> dates, int target, {DateTime? today}) {
    final ref = today ?? DateTime.now();
    final set = _validDates(dates, AppDates.todayKey(ref));
    if (set.isEmpty) return 0;

    // Hafta başına sayımlar bir kez çıkarılır (uzun geçmişte O(n)).
    final perWeek = <String, int>{};
    for (final d in set) {
      final w = AppDates.weekKey(AppDates.parseKey(d));
      perWeek[w] = (perWeek[w] ?? 0) + 1;
    }

    final thisWeek = AppDates.weekKey(ref);
    final thisCount = perWeek[thisWeek] ?? 0;
    var streak = 0;
    var offset = 0;
    if (thisCount >= target) {
      streak = 1;
      offset = 1;
    } else if (thisCount + _daysLeftInWeek(set, ref) >= target) {
      offset = 1;
    } else {
      return 0;
    }

    while (true) {
      final week = AppDates.weekKey(AppDates.daysBefore(ref, 7 * offset));
      if ((perWeek[week] ?? 0) < target) break;
      streak++;
      offset++;
    }
    return streak;
  }

  /// Bu hafta içinde hâlâ işaretlenebilecek gün sayısı (bugün tamamlandıysa
  /// bugün sayılmaz).
  static int _daysLeftInWeek(Set<String> dates, DateTime ref) {
    final remainingIncludingToday = 8 - ref.weekday;
    return dates.contains(AppDates.todayKey(ref))
        ? remainingIncludingToday - 1
        : remainingIncludingToday;
  }

  static int _dailyStreak(Set<String> dates, DateTime ref) {
    final yesterday = AppDates.daysBefore(ref, 1);
    var cursor = dates.contains(AppDates.todayKey(ref)) ? ref : yesterday;

    var streak = 0;
    while (dates.contains(AppDates.todayKey(cursor))) {
      streak++;
      cursor = AppDates.daysBefore(cursor, 1);
    }
    return streak;
  }

  static int _weeklyStreak(Set<String> dates, DateTime ref) {
    final weeks = dates.map((d) => AppDates.weekKey(AppDates.parseKey(d))).toSet();
    final thisWeek = AppDates.weekKey(ref);
    final lastWeek = AppDates.weekKey(AppDates.daysBefore(ref, 7));

    var cursor = weeks.contains(thisWeek) ? thisWeek : lastWeek;

    var streak = 0;
    while (weeks.contains(cursor)) {
      streak++;
      cursor = AppDates.weekKey(AppDates.daysBefore(AppDates.parseKey(cursor), 7));
    }
    return streak;
  }

  /// Seri artık kurtarılamıyorsa true. Esnek modda bu haftanın hedefi hâlâ
  /// tutturulabiliyorsa kırılmış sayılmaz.
  static bool isStreakBroken(Habit habit, {required String today, String? yesterday}) {
    final dates = _validDates(habit.completionDates, today);
    if (dates.isEmpty) return false;
    if (habit.flexStreakEnabled && habit.frequency == HabitFrequency.daily) {
      final ref = AppDates.parseKey(today);
      final count = weekCompletionCount(dates, AppDates.weekKey(ref));
      return count + _daysLeftInWeek(dates, ref) < habit.flexTargetPerWeek;
    }
    return computeStreak(habit, today: today) == 0;
  }

  /// Bugüne kadar (bugün dahil) geçerli, tekrarsız tarih anahtarları.
  static Set<String> _validDates(Iterable<String> dates, String today) {
    return dates.where((d) => AppDates.isValidKey(d) && d.compareTo(today) <= 0).toSet();
  }
}
