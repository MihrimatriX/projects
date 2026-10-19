import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaman_takip_ve_pomodoro_araci/app.dart';
import 'package:zaman_takip_ve_pomodoro_araci/core/settings/app_settings.dart';
import 'package:zaman_takip_ve_pomodoro_araci/data/database.dart';
import 'package:zaman_takip_ve_pomodoro_araci/data/database_provider.dart';
import 'package:zaman_takip_ve_pomodoro_araci/features/pomodoro/pomodoro_controller.dart';
import 'package:zaman_takip_ve_pomodoro_araci/features/timer/pause_store.dart';

const s = AppSettings(workMinutes: 25, breakMinutes: 5, longBreakMinutes: 15);
final t0 = DateTime(2026, 10, 5, 9);

PomodoroState fresh() => const PomodoroState(remaining: 25 * 60, total: 25 * 60);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PomodoroState (duvar saati)', () {
    test('kalan sure bitis anindan hesaplanir; tik sikligi onemsiz', () {
      final p = fresh().start(t0);
      expect(p.remainingAt(t0.add(const Duration(minutes: 10, milliseconds: 1))), 15 * 60);
      // Hic tik gelmeden 30 dk gecse de (uyku, donmus arayuz) tek tikte tam bir faz biter.
      final after = p.tick(t0.add(const Duration(minutes: 30)), s);
      expect(after.work, isFalse);
      expect(after.running, isFalse);
      expect(after.remaining, 5 * 60);
      expect(after.tomatoesOn(t0), 1);
    });

    test('duraklatma kalan sureyi korur, devam bitisi kaydirir', () {
      var p = fresh().start(t0).pause(t0.add(const Duration(minutes: 5)));
      expect(p.running, isFalse);
      expect(p.remaining, 20 * 60);
      p = p.start(t0.add(const Duration(hours: 1)));
      expect(p.endAt, t0.add(const Duration(hours: 1, minutes: 20)));
    });

    test('4. odaktan sonra uzun mola, moladan sonra faz 1', () {
      var p = fresh();
      var now = t0;
      for (var i = 0; i < 4; i++) {
        p = p.start(now);
        now = now.add(Duration(seconds: p.remaining));
        p = p.tick(now, s); // odak bitti
        if (i < 3) {
          p = p.start(now);
          now = now.add(Duration(seconds: p.remaining));
          p = p.tick(now, s); // kisa mola bitti
        }
      }
      expect(p.work, isFalse);
      expect(p.total, 15 * 60);
      expect(p.tomatoesOn(now), 4);
      p = p.complete(now, s);
      expect((p.work, p.phase), (true, 1));
    });

    test('atlanan odak domates sayilmaz; gun degisince sayac sifirlanir', () {
      final skipped = fresh().start(t0).complete(t0.add(const Duration(minutes: 1)), s, skipped: true);
      expect(skipped.tomatoesOn(t0), 0);
      expect(skipped.work, isFalse);

      final done = fresh().start(t0).tick(t0.add(const Duration(minutes: 25)), s);
      expect(done.tomatoesOn(t0.add(const Duration(days: 1))), 0);
    });

    test('dun biten (uygulama kapaliyken) odak bugune yazilmaz', () {
      final p = fresh().start(t0);
      final nextDay = t0.add(const Duration(days: 1));
      final after = p.tick(nextDay, s);
      expect(after.work, isFalse);
      expect(after.tomatoesOn(nextDay), 0);
    });

    test('ayar degisimi uzun molada uzun mola suresini kullanir; JSON gidis-donus', () {
      const longBreak = PomodoroState(work: false, phase: 4, remaining: 60, total: 60);
      expect(longBreak.withSettings(s).total, 15 * 60);
      final running = fresh().start(t0);
      expect(identical(running.withSettings(s.copyWith(workMinutes: 50)), running), isTrue);
      final back = PomodoroState.fromJson(running.toJson());
      expect(back.endAt, running.endAt);
      expect(back.running, isTrue);
    });
  });

  group('PomodoroNotifier kaliciligi', () {
    test('calisan pomodoro yeniden acilista bitis anindan devam eder', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer make() => ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);

      final c1 = make();
      final n1 = c1.read(pomodoroProvider.notifier)..clock = () => t0;
      n1.start();
      c1.dispose(); // uygulama kapandi

      final c2 = make();
      addTearDown(c2.dispose);
      final n2 = c2.read(pomodoroProvider.notifier)..clock = () => t0.add(const Duration(minutes: 10));
      final st = c2.read(pomodoroProvider);
      expect(st.running, isTrue);
      expect(st.remainingAt(t0.add(const Duration(minutes: 10))), 15 * 60);
      n2.clock = () => t0.add(const Duration(minutes: 26));
      n2.tick();
      expect(c2.read(pomodoroProvider).work, isFalse);
      expect(c2.read(pomodoroProvider).running, isFalse);
    });
  });

  group('Sure kaydi duraklatma', () {
    test('net sure duraklatmalari duser', () {
      final start = t0;
      var p = const PauseInfo().pause(start.add(const Duration(minutes: 10)));
      p = p.resume(start.add(const Duration(minutes: 25)));
      expect(p.trackedAt(start, start.add(const Duration(minutes: 40))), const Duration(minutes: 25));
      p = p.pause(start.add(const Duration(minutes: 40)));
      // Duraklatilmisken saat ilerlese de net sure artmaz.
      expect(p.trackedAt(start, start.add(const Duration(hours: 5))), const Duration(minutes: 25));
    });

    test('duraklatma yalnizca ayni kayda yuklenir ve kalici', () async {
      SharedPreferences.setMockInitialValues({});
      final store = PauseStore(await SharedPreferences.getInstance());
      await store.save(7, PauseInfo(accum: const Duration(minutes: 3), pausedAt: t0));
      final back = store.load(7);
      expect(back.accum, const Duration(minutes: 3));
      expect(back.pausedAt, t0);
      expect(store.load(8).paused, isFalse);
      await store.clear();
      expect(store.load(7).paused, isFalse);
    });
  });

  test('gun sorgusu takvim gunune gore; durdurma duraklatmayi duser (bellek ici drift)', () async {
    final db = AppDatabase.test();
    addTearDown(db.close);
    final pid = await db.insertProject('P');
    Future<void> add(DateTime a, DateTime b) => db.into(db.timeEntries).insert(
          TimeEntriesCompanion.insert(projectId: pid, startedAt: a, endedAt: Value(b)),
        );
    await add(DateTime(2026, 3, 29, 23, 30), DateTime(2026, 3, 29, 23, 50));
    await add(DateTime(2026, 3, 30, 0, 10), DateTime(2026, 3, 30, 0, 40));
    expect((await db.getEntriesForDay(DateTime(2026, 3, 29))).length, 1);
    expect(await db.dayTotal(DateTime(2026, 3, 30)), const Duration(minutes: 30));
    expect((await db.dayByProject(DateTime(2026, 3, 29)))[pid], const Duration(minutes: 20));
  });

  testWidgets('pomodoro sekme degisince durmaz', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.test();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const MyApp(),
    ));
    await tester.pump();
    await tester.tap(find.text('Pomodoro').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başlat'));
    await tester.pump();
    expect(find.text('Ara Ver'), findsOneWidget);

    await tester.tap(find.text('Timer').first);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Pomodoro').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ara Ver'), findsOneWidget);
    expect(find.textContaining('Odak seansı'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
