import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/app.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/database/app_database.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/database/database_provider.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/notes/presentation/notes_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  void desktopView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Gerçek (bellek içi) SQLite ile uygulama; DB işlemleri gerçek zamanlı akar.
  Future<AppDatabase> pumpWithDb(WidgetTester tester, Widget child) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: child,
      ),
    );
    await settle(tester);
    return db;
  }

  testWidgets('ana kabuk yüklenir', (WidgetTester tester) async {
    desktopView(tester);
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    // Gerçek zamanlı bekleme yok: google_fonts testte ağdan font indirmeye çalışmasın.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bugün'), findsWidgets);
    expect(find.text('Akıllı Liste'), findsOneWidget);
  });

  testWidgets('not ekle, düzenle, sil ve geri al', (WidgetTester tester) async {
    desktopView(tester);
    final db = await pumpWithDb(
      tester,
      const MaterialApp(home: Scaffold(body: NotesScreen())),
    );

    await tester.enterText(find.byKey(const Key('note-input')), 'Süt al');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Süt al'), findsOneWidget);

    await tester.tap(find.byTooltip('Düzenle'));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('note-edit')), 'Süt ve ekmek al');
    await tester.tap(find.text('Kaydet'));
    await settle(tester);
    expect(find.text('Süt ve ekmek al'), findsOneWidget);
    final rows = await tester.runAsync(() => db.select(db.quickNotes).get());
    expect(rows!.single.body, 'Süt ve ekmek al');

    await tester.tap(find.byTooltip('Sil'));
    await settle(tester);
    expect(find.text('Süt ve ekmek al'), findsNothing);
    await tester.tap(find.text('Geri al'));
    await settle(tester);
    expect(find.text('Süt ve ekmek al'), findsOneWidget);
    final after = await tester.runAsync(() => db.select(db.quickNotes).get());
    expect(after!.single.body, 'Süt ve ekmek al');

    await tester.enterText(find.byKey(const Key('note-search')), 'yok');
    await tester.pump();
    expect(find.textContaining('eşleşen not yok'), findsOneWidget);
  });
}

/// SQLite gerçek async çalışır; FakeAsync'te bitmesi için gerçek zamanlı bekle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}
