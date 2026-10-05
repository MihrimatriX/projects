import 'package:flutter_test/flutter_test.dart';
import 'package:aliskanlik_takipcisi/core/date_utils.dart';
import 'package:aliskanlik_takipcisi/core/streak_logic.dart';
import 'package:aliskanlik_takipcisi/core/weekly_report.dart';
import 'package:aliskanlik_takipcisi/features/chain/chain_groups.dart';
import 'package:aliskanlik_takipcisi/features/habits/models/habit.dart';
import 'package:intl/date_symbol_data_local.dart';

/// [end] gününden geriye [n] ardışık günün anahtarları.
List<String> run(String end, int n) {
  final d = AppDates.parseKey(end);
  return List.generate(n, (i) => AppDates.todayKey(AppDates.daysBefore(d, i)));
}

int daily(List<String> dates, String today) => StreakLogic.computeStreak(
      Habit(id: 'h', title: 'H', completionDates: dates),
      today: today,
    );

void main() {
  group('AppDates', () {
    test('daysBefore yaz saati geçişlerinde günü atlamaz/tekrarlamaz', () {
      // AB yaz saati: 29 Mart 2026 ve 25 Ekim 2026; ABD: 8 Mart, 1 Kasım.
      for (final key in ['2026-03-30', '2026-10-26', '2026-03-09', '2026-11-02']) {
        final d = AppDates.parseKey(key);
        final prev = AppDates.todayKey(AppDates.daysBefore(d, 1));
        final prev2 = AppDates.todayKey(AppDates.daysBefore(d, 2));
        expect(prev.compareTo(key), lessThan(0));
        expect(prev2.compareTo(prev), lessThan(0));
        expect(AppDates.parseKey(key).difference(AppDates.parseKey(prev)).inHours, inInclusiveRange(23, 25));
      }
    });

    test('ay, yıl ve artık yıl sınırları', () {
      expect(AppDates.yesterdayKey(DateTime(2026, 1, 1)), '2025-12-31');
      expect(AppDates.yesterdayKey(DateTime(2024, 3, 1)), '2024-02-29');
      expect(AppDates.yesterdayKey(DateTime(2025, 3, 1)), '2025-02-28');
    });

    test('weekKey haftanın pazartesisini verir; hafta yıl sınırını aşabilir', () {
      expect(AppDates.weekKey(DateTime(2026, 10, 5)), '2026-10-05'); // Pazartesi
      expect(AppDates.weekKey(DateTime(2026, 10, 11)), '2026-10-05'); // Pazar
      expect(AppDates.weekKey(DateTime(2027, 1, 1)), '2026-12-28');
      expect(AppDates.weekKey(DateTime(2026, 3, 29, 3, 30)), '2026-03-23');
    });

    test('isValidKey biçimi ve takvimi doğrular', () {
      expect(AppDates.isValidKey('2024-02-29'), isTrue);
      expect(AppDates.isValidKey('2025-02-29'), isFalse);
      expect(AppDates.isValidKey('2025-13-01'), isFalse);
      expect(AppDates.isValidKey('2025-1-01'), isFalse);
      expect(AppDates.isValidKey('dün'), isFalse);
    });

    test('lastNDays bugün ile biter ve sıralıdır', () {
      final keys = AppDates.lastNDays(3, DateTime(2026, 3, 1));
      expect(keys, ['2026-02-27', '2026-02-28', '2026-03-01']);
    });
  });

  group('Günlük seri', () {
    test('bugün dahil ardışık günler', () {
      expect(daily(run('2026-10-05', 5), '2026-10-05'), 5);
    });

    test('bugün henüz yapılmadıysa dünden geriye sayılır', () {
      expect(daily(run('2026-10-04', 3), '2026-10-05'), 3);
    });

    test('bir gün kaçırılırsa seri sıfırlanır', () {
      expect(daily(run('2026-10-03', 10), '2026-10-05'), 0);
    });

    test('aradaki boşluk eski kısmı keser', () {
      final dates = [...run('2026-10-05', 2), ...run('2026-10-01', 5)];
      expect(daily(dates, '2026-10-05'), 2);
    });

    test('yaz saati geçişinden geçen seri kesintisiz sayılır', () {
      expect(daily(run('2026-03-31', 6), '2026-03-31'), 6);
      expect(daily(run('2026-10-27', 6), '2026-10-27'), 6);
    });

    test('ay/yıl/artık yıl sınırından geçen seri', () {
      expect(daily(run('2027-01-02', 5), '2027-01-02'), 5);
      expect(daily(run('2024-03-02', 4), '2024-03-02'), 4);
    });

    test('tekrarlanan ve geçersiz tarihler sayılmaz', () {
      final dates = ['2026-10-05', '2026-10-05', '2026-10-04', 'bozuk', '2026-02-30'];
      expect(daily(dates, '2026-10-05'), 2);
    });

    test('saat dilimi değişince "bugün"den ileri tarihler seriye katılmaz', () {
      // Batıya uçuş: kayıt 6 Ekim'e atılmış ama yerel gün hâlâ 5 Ekim.
      expect(daily(['2026-10-06', ...run('2026-10-05', 3)], '2026-10-05'), 3);
      expect(daily(['2026-10-06'], '2026-10-05'), 0);
    });

    test('sırasız kayıtlar doğru sayılır', () {
      expect(daily(['2026-10-03', '2026-10-05', '2026-10-04'], '2026-10-05'), 3);
    });

    test('uzun geçmiş hızlı hesaplanır', () {
      final dates = run('2026-10-05', 3650);
      final sw = Stopwatch()..start();
      expect(daily(dates, '2026-10-05'), 3650);
      expect(StreakLogic.flexWeeklyStreak(dates, 7, today: DateTime(2026, 10, 5)), greaterThan(500));
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('isStreakBroken: dün yapıldıysa kırık değil, iki gün boşsa kırık', () {
      final h = Habit(id: 'h', title: 'H', completionDates: run('2026-10-04', 2));
      expect(StreakLogic.isStreakBroken(h, today: '2026-10-05'), isFalse);
      expect(StreakLogic.isStreakBroken(h, today: '2026-10-06'), isTrue);
      expect(StreakLogic.isStreakBroken(const Habit(id: 'e', title: 'E'), today: '2026-10-06'), isFalse);
    });
  });

  group('Haftalık seri', () {
    Habit weekly(List<String> dates) =>
        Habit(id: 'w', title: 'W', frequency: HabitFrequency.weekly, completionDates: dates);

    test('ardışık haftalar sayılır, bu hafta boşsa geçen haftadan başlar', () {
      final dates = ['2026-10-05', '2026-09-30', '2026-09-21'];
      expect(StreakLogic.computeStreak(weekly(dates), today: '2026-10-07'), 3);
      expect(StreakLogic.computeStreak(weekly(dates.skip(1).toList()), today: '2026-10-07'), 2);
    });

    test('bir hafta atlanırsa seri biter', () {
      expect(StreakLogic.computeStreak(weekly(['2026-09-21']), today: '2026-10-07'), 0);
    });

    test('yıl sınırını aşan haftalar', () {
      final dates = ['2027-01-01', '2026-12-22', '2026-12-15'];
      expect(StreakLogic.computeStreak(weekly(dates), today: '2027-01-03'), 3);
    });
  });

  group('Esnek seri', () {
    test('hedefi tutturan haftalar sayılır', () {
      // 21-27 Eylül ve 28 Eyl-4 Eki haftalarında 5'er gün; bugün Pazartesi.
      final dates = [...run('2026-09-25', 5), ...run('2026-10-02', 5)];
      expect(StreakLogic.flexWeeklyStreak(dates, 5, today: DateTime(2026, 10, 5)), 2);
    });

    test('bu hafta hedefe ulaştıysa o da sayılır', () {
      final dates = [...run('2026-10-09', 5), ...run('2026-10-02', 5)];
      expect(StreakLogic.flexWeeklyStreak(dates, 5, today: DateTime(2026, 10, 9)), 2);
    });

    test('bu hafta artık yetişemiyorsa seri kırılır', () {
      // Cumartesi, bu hafta 1 gün; kalan 2 günle 5'e ulaşılamaz.
      final dates = ['2026-10-05', ...run('2026-10-02', 5)];
      final h = Habit(
        id: 'f',
        title: 'F',
        flexStreakEnabled: true,
        flexTargetPerWeek: 5,
        completionDates: dates,
      );
      expect(StreakLogic.computeStreak(h, today: '2026-10-10'), 0);
      expect(StreakLogic.isStreakBroken(h, today: '2026-10-10'), isTrue);
      expect(StreakLogic.isStreakBroken(h, today: '2026-10-07'), isFalse);
    });

    test('bugün tamamlandıysa kalan gün hesabında iki kez sayılmaz', () {
      // Pazar: bu hafta 6 gün, bugün dahil. Hedef 7 → artık mümkün değil.
      final dates = run('2026-10-11', 6);
      expect(StreakLogic.flexWeeklyStreak(dates, 7, today: DateTime(2026, 10, 11)), 0);
      expect(StreakLogic.flexWeeklyStreak(dates, 6, today: DateTime(2026, 10, 11)), 1);
    });

    test('weekCompletionCount tekrarları tek sayar', () {
      expect(StreakLogic.weekCompletionCount(['2026-10-05', '2026-10-05', '2026-10-06'], '2026-10-05'), 2);
    });

    test('currentWeekProgress verilen haftaya göre sayar', () {
      final habit = Habit(id: '1', title: 'Su', flexStreakEnabled: true, completionDates: run('2026-10-07', 3));
      expect(StreakLogic.currentWeekProgress(habit, today: DateTime(2026, 10, 7)), 3);
    });
  });

  test('haftalık rapor yaz saati haftasında doğru aralığı yazar', () async {
    await initializeDateFormatting('tr_TR');
    final report = WeeklyReport.generate(
      [Habit(id: 'a', title: 'Koşu', streak: 2, completionDates: run('2026-10-27', 3))],
      now: DateTime(2026, 10, 27),
    );
    expect(report, contains('26 Eki – 1 Kas'));
    expect(report, contains('Bu hafta: 2'));
  });

  test('döngüsel zincir sonsuz döngüye girmez', () {
    const a = Habit(id: 'a', title: 'A', chainFromId: 'b');
    const b = Habit(id: 'b', title: 'B', chainFromId: 'a');
    expect(buildChainGroups([a, b]), hasLength(2));
  });
}
