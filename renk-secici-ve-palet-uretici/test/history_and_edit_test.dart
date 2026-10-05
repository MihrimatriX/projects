import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renk_secici_ve_palet_uretici/app.dart';
import 'package:renk_secici_ve_palet_uretici/data/palette_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('palet gecmisi', () {
    test('bozuk JSON bos liste doner ve yeni kayit eklenebilir', () async {
      SharedPreferences.setMockInitialValues({'palet:history': '{bozuk'});
      final repo = PaletteHistoryRepository();
      expect(await repo.load(), isEmpty);
      await repo.add(['#111111', '#222222']);
      expect((await repo.load()).single.colors, ['#111111', '#222222']);
    });

    test('gecersiz HEX iceren veya eksik alanli girdiler atlanir', () async {
      SharedPreferences.setMockInitialValues({
        'palet:history':
            '[{"colors":["#abc","#123456"],"date":"2026-01-01T00:00:00.000"},'
                '{"colors":["kirmizi"],"date":"2026-01-01T00:00:00.000"},'
                '{"colors":[],"date":"2026-01-01T00:00:00.000"},'
                '{"date":"2026-01-01T00:00:00.000"}]',
      });
      final list = await PaletteHistoryRepository().load();
      expect(list.length, 1);
      expect(list.single.colors, ['#AABBCC', '#123456']);
    });

    test('ayni palet ust uste eklenmez, en fazla 20 kayit tutulur', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PaletteHistoryRepository();
      await repo.add(['#000000']);
      await repo.add(['#000000']);
      expect((await repo.load()).length, 1);
      for (var i = 0; i < 25; i++) {
        await repo.add(['#${i.toRadixString(16).padLeft(6, '0')}']);
      }
      expect((await repo.load()).length, PaletteHistoryRepository.maxItems);
    });
  });

  testWidgets('E ile HEX duzenlenir; gecersiz girdi hata gosterir, gecerli renk kilitlenir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PaletteApp());
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();
    expect(find.text('Renk 3 — HEX düzenle'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('hex-input')), 'mavi');
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Geçerli bir HEX'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('hex-input')), '#38f');
    await tester.tap(find.text('Uygula'));
    await tester.pumpAndSettle();
    expect(find.text('Renk 3 — HEX düzenle'), findsNothing);
    expect(find.text('#3388FF'), findsOneWidget);

    // Kilitli olduğu için yeni palet üretiminde korunur.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('#3388FF'), findsOneWidget);
  });

  testWidgets('disa aktarma diyalogunda JSON sekmesi', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PaletteApp());
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, contains('"palette-1"'));
    expect(field.controller!.text, isNot(contains('/*')));
  });
}
