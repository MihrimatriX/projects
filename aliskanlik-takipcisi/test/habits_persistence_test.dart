import 'dart:convert';

import 'package:aliskanlik_takipcisi/features/habits/data/habits_repository.dart';
import 'package:aliskanlik_takipcisi/features/habits/models/habit.dart';
import 'package:aliskanlik_takipcisi/features/habits/providers/habits_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String encode(List<Habit> habits) => jsonEncode(habits.map((h) => h.toJson()).toList());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HabitsRepository', () {
    test('kaydet/oku gidiş-dönüş tüm alanları korur', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = HabitsRepository();
      const habit = Habit(
        id: 'a',
        title: 'Kitap "oku" İğdır',
        icon: '📚',
        color: 0xFF112233,
        frequency: HabitFrequency.weekly,
        completionDates: ['2026-10-05'],
        flexStreakEnabled: true,
        flexTargetPerWeek: 4,
        chainFromId: 'b',
      );
      await repo.save([habit]);
      final loaded = await repo.load(now: DateTime(2026, 10, 5, 12));
      expect(loaded.single.toJson()..remove('streak')..remove('doneToday'),
          habit.toJson()..remove('streak')..remove('doneToday'));
      expect(loaded.single.doneToday, isTrue);
    });

    test('yeni günde doneToday sıfırlanır, kaçırılan gün seriyi kırar', () async {
      SharedPreferences.setMockInitialValues({
        'habits_v2': encode([
          const Habit(id: 'a', title: 'A', doneToday: true, streak: 3,
              completionDates: ['2026-10-03', '2026-10-04', '2026-10-05']),
        ]),
      });
      final repo = HabitsRepository();
      var h = (await repo.load(now: DateTime(2026, 10, 6, 0, 1))).single;
      expect(h.doneToday, isFalse);
      expect(h.streak, 3, reason: 'dün yapıldı, seri bugün hâlâ kurtarılabilir');

      h = (await repo.load(now: DateTime(2026, 10, 7, 9))).single;
      expect(h.streak, 0);
      // Normalleştirilmiş hâl kalıcı yazılmış olmalı.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('habits_v2'), contains('"streak":0'));
    });

    test('saat dilimi geri gidince bugünkü kayıt "yapıldı" olarak görünür', () async {
      SharedPreferences.setMockInitialValues({
        'habits_v2': encode([
          const Habit(id: 'a', title: 'A', doneToday: false, completionDates: ['2026-10-05']),
        ]),
      });
      final h = (await HabitsRepository().load(now: DateTime(2026, 10, 5, 23))).single;
      expect(h.doneToday, isTrue);
      expect(h.streak, 1);
    });

    test('bozuk JSON yedeklenir, ezilmez', () async {
      SharedPreferences.setMockInitialValues({'habits_v2': '[{"id": "a", "title": '});
      final habits = await HabitsRepository().load(now: DateTime(2026, 10, 5));
      expect(habits, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      final backups = prefs.getKeys().where((k) => k.startsWith(HabitsRepository.backupKeyPrefix));
      expect(backups, hasLength(1));
      expect(prefs.getString(backups.first), '[{"id": "a", "title": ');
    });

    test('tek bozuk kayıt diğerlerini düşürmez ve ham veri yedeklenir', () async {
      SharedPreferences.setMockInitialValues({
        'habits_v2': '[{"id":"a","title":"A"},{"id":5},{"id":"c","title":"C"}]',
      });
      final habits = await HabitsRepository().load(now: DateTime(2026, 10, 5));
      expect(habits.map((h) => h.id), ['a', 'c']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().any((k) => k.startsWith(HabitsRepository.backupKeyPrefix)), isTrue);
    });

    test('v1 verisi v2ye taşınır', () async {
      SharedPreferences.setMockInitialValues({
        'habits_v1': '[{"id":"x","title":"Eski","doneToday":true,"streak":4,"lastCompletedDate":"2026-10-04"}]',
      });
      final h = (await HabitsRepository().load(now: DateTime(2026, 10, 5))).single;
      expect(h.title, 'Eski');
      expect(h.completionDates, ['2026-10-04']);
      expect(h.streak, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('habits_v1'), isFalse);
    });

    test('decodeHabits hatalı içe aktarmayı Türkçe nedenle reddeder', () {
      expect(() => HabitsRepository.decodeHabits('selam'),
          throwsA(isA<FormatException>().having((e) => e.message, 'm', contains('JSON'))));
      expect(() => HabitsRepository.decodeHabits('{"id":"a"}'), throwsFormatException);
      expect(() => HabitsRepository.decodeHabits('[{"id":"a","title":"A","completionDates":["2025-02-30"]}]'),
          throwsA(isA<FormatException>().having((e) => e.message, 'm', contains('1. kayıt'))));
      expect(() => HabitsRepository.decodeHabits('[{"id":"a","title":"A"},{"id":"a","title":"B"}]'),
          throwsA(isA<FormatException>().having((e) => e.message, 'm', contains('tekrarlanan'))));
    });

    test('CSV tırnakları kaçışlar', () {
      final csv = HabitsRepository().exportCsv(const [
        Habit(id: 'a', title: 'Su "iç"', completionDates: ['2026-10-05', '2026-10-04']),
      ]);
      expect(csv.split('\n')[1], '"a","Su ""iç""","🌱",daily,0,"2026-10-05;2026-10-04"');
    });
  });

  group('HabitsNotifier', () {
    late DateTime now;
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 10, 5, 10);
      container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
    });
    tearDown(() => container.dispose());

    Future<HabitsNotifier> ready() async {
      await container.read(habitsProvider.future);
      return container.read(habitsProvider.notifier);
    }

    List<Habit> habits() => container.read(habitsProvider).value!;

    test('ekle, check-in, geri al, sil akışı kalıcıdır', () async {
      final n = await ready();
      await n.add(title: '  Su iç  ');
      await n.add(title: '   ');
      expect(habits().single.title, 'Su iç');

      final id = habits().single.id;
      await n.toggle(id);
      expect(habits().single.doneToday, isTrue);
      expect(habits().single.streak, 1);

      // Yeniden açılış: aynı veriler diskten gelir.
      final c2 = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
      addTearDown(c2.dispose);
      expect((await c2.read(habitsProvider.future)).single.completionDates, ['2026-10-05']);

      await n.toggle(id);
      expect(habits().single.doneToday, isFalse);
      expect(habits().single.completionDates, isEmpty);

      await n.remove(id);
      expect(habits(), isEmpty);
    });

    test('unutulan geçmiş gün sonradan işaretlenince seri birleşir', () async {
      final n = await ready();
      await n.add(title: 'Koşu');
      final id = habits().single.id;
      await n.toggleOn(id, '2026-10-03');
      await n.toggle(id);
      expect(habits().single.streak, 1, reason: '4 Ekim eksik');
      await n.toggleOn(id, '2026-10-04');
      expect(habits().single.streak, 3);
      // Gelecek gün ve geçersiz tarih reddedilir.
      await n.toggleOn(id, '2026-10-06');
      await n.toggleOn(id, '2026-02-30');
      expect(habits().single.completionDates, ['2026-10-03', '2026-10-04', '2026-10-05']);
    });

    test('gece yarısı geçince açık uygulamada durum yenilenir', () async {
      final n = await ready();
      await n.add(title: 'Kitap');
      await n.toggle(habits().single.id);
      expect(habits().single.doneToday, isTrue);

      now = DateTime(2026, 10, 6, 0, 2);
      await n.refreshDay();
      expect(habits().single.doneToday, isFalse);
      expect(habits().single.streak, 1);

      now = DateTime(2026, 10, 7, 8);
      await n.refreshDay();
      expect(habits().single.streak, 0);
    });

    test('zincir hatırlatıcısı yalnızca bugünkü tamamlamada döner', () async {
      final n = await ready();
      await n.add(title: 'A');
      final a = habits().single.id;
      await n.add(title: 'B', chainFromId: a);
      expect((await n.toggleOn(a, '2026-10-04')).chainReminders, isEmpty);
      expect((await n.toggle(a)).chainReminders.single.title, 'B');
    });

    test('JSON dışa aktar → içe aktar aynı veriyi geri getirir', () async {
      final n = await ready();
      await n.add(title: 'Su');
      await n.toggle(habits().single.id);
      final json = await n.exportJson();

      await n.remove(habits().single.id);
      expect(habits(), isEmpty);

      expect(await n.importJson(json), 1);
      expect(habits().single.title, 'Su');
      expect(habits().single.doneToday, isTrue);
    });

    test('hatalı içe aktarma mevcut veriye dokunmaz', () async {
      final n = await ready();
      await n.add(title: 'Su');
      await expectLater(n.importJson('[{"title":"eksik id"}]'), throwsFormatException);
      expect(habits().single.title, 'Su');
    });

    test('içe aktarmada olmayan zincir kaynağı temizlenir', () async {
      final n = await ready();
      await n.importJson('[{"id":"a","title":"A","chainFromId":"yok"}]');
      expect(habits().single.chainFromId, isNull);
    });
  });
}
