import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliskanlik_takipcisi/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/');
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await bootstrap();
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('ana ekran yuklenir', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('Bugün'), findsNWidgets(2));
    expect(find.text('Check-in'), findsNothing);
    expect(find.text('Henüz alışkanlık yok'), findsOneWidget);
  });

  testWidgets('alışkanlık ekle ve check-in yap', (WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('İlk alışkanlığı ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Meditasyon');
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Meditasyon'), findsOneWidget);
    expect(find.text('Bugünkü alışkanlıklar tamamlandı'), findsNothing);

    await tester.tap(find.text('Meditasyon'));
    await tester.pumpAndSettle();
    expect(find.text('Bugünkü alışkanlıklar tamamlandı'), findsOneWidget);
    expect(find.textContaining('1 gün seri'), findsOneWidget);

    // Kalıcılık: kayıt SharedPreferences'a yazıldı.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('habits_v2'), contains('Meditasyon'));
  });

  testWidgets('ayarlar: panodan JSON içe aktarma', (WidgetTester tester) async {
    const backup = '[{"id":"a","title":"Kitap oku","icon":"📚"}]';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': backup};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await pumpApp(tester);
    await tester.tap(find.text('Ayarlar').last);
    await tester.pumpAndSettle();
    // Masaüstü test ortamında zamanlanmış bildirim yok: sahte anahtar gösterilmez.
    expect(find.text('Günlük hatırlatıcı'), findsNothing);

    final importButton = find.text('JSON içe aktar (panodan)');
    await tester.scrollUntilVisible(importButton, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(importButton);
    await tester.pumpAndSettle();
    expect(find.text('Yedekten geri yükle'), findsOneWidget);
    await tester.tap(find.text('Geri yükle'));
    await tester.pumpAndSettle();
    expect(find.text('1 alışkanlık içe aktarıldı'), findsOneWidget);

    await tester.tap(find.text('Bugün').last);
    await tester.pumpAndSettle();
    expect(find.text('Kitap oku'), findsOneWidget);
  });
}
