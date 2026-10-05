import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaman_takip_ve_pomodoro_araci/app.dart';
import 'package:zaman_takip_ve_pomodoro_araci/core/settings/app_settings.dart';
import 'package:zaman_takip_ve_pomodoro_araci/data/database.dart';
import 'package:zaman_takip_ve_pomodoro_araci/data/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('timer ekrani acilir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.test();

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWith((ref) {
            ref.onDispose(db.close);
            return db;
          }),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Süre Kaydı'), findsOneWidget);
    expect(find.text('Odaklanma'), findsWidgets);

    await db.close();
  });
}
