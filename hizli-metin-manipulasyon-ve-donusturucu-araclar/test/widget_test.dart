import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hizli_metin_manipulasyon_ve_donusturucu_araclar/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, [Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
  }

  Finder inputField() => find.widgetWithText(TextField, 'Metninizi buraya yapıştırın…');

  Future<void> selectTool(WidgetTester tester, String query, String name) async {
    await tester.enterText(find.byType(TextField).first, query);
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> typeInput(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  testWidgets('ana ekran ve sidebar yüklenir', (WidgetTester tester) async {
    await pumpApp(tester);
    expect(find.text('● Çevrimdışı çalışır'), findsOneWidget);
    expect(find.text('Base64 encode'), findsWidgets);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(inputField(), findsOneWidget);
    expect(find.text('Panoya Kopyala'), findsOneWidget);
  });

  testWidgets('Türkçe büyük harf, çıktıyı girdi yap ve araç hatırlanır', (WidgetTester tester) async {
    await pumpApp(tester);
    await selectTool(tester, 'buyuk', 'BÜYÜK HARF (Türkçe)');
    await tester.pumpAndSettle();
    await typeInput(tester, 'istanbul ılık');
    expect(find.text('İSTANBUL ILIK'), findsOneWidget);

    // Zincirleme: çıktı girdiye geçer, sonra Türkçe küçük harfe çevrilir.
    await tester.tap(find.byTooltip('Çıktıyı girdi yap (Ctrl+Shift+Enter)'));
    await tester.pumpAndSettle();
    await selectTool(tester, 'kucuk', 'küçük harf (Türkçe)');
    await tester.pumpAndSettle();
    expect(find.text('İSTANBUL ILIK'), findsOneWidget, reason: 'girdi = önceki çıktı');
    expect(find.text('istanbul ılık'), findsOneWidget, reason: 'yeni çıktı');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('last_tool_id'), 'lower-tr');
  });

  testWidgets('son kullanılan araç açılışta geri yüklenir', (WidgetTester tester) async {
    await pumpApp(tester, {'last_tool_id': 'slug'});
    expect(find.text('Slug (URL dostu)'), findsWidgets, reason: 'başlıkta seçili araç');
    await typeInput(tester, 'Çalışma Şekli');
    expect(find.text('calisma-sekli'), findsOneWidget);
  });

  testWidgets('hatalı girdi hata olarak gösterilir, kopyalama kapanır', (WidgetTester tester) async {
    await pumpApp(tester);
    await selectTool(tester, 'base64', 'Base64 decode');
    await tester.pumpAndSettle();
    await typeInput(tester, '@@@@');
    expect(find.text('Dönüşüm hatası'), findsOneWidget);
    final copy = tester.widget<OutlinedButton>(find.ancestor(
      of: find.text('Panoya Kopyala'),
      matching: find.byWidgetPredicate((w) => w is OutlinedButton),
    ));
    expect(copy.onPressed, isNull);
  });

  testWidgets('büyük girdi arka planda işlenir ve önizleme kısaltılır', (WidgetTester tester) async {
    await pumpApp(tester);
    await selectTool(tester, 'buyuk', 'BÜYÜK HARF (Türkçe)');
    await tester.pumpAndSettle();

    final big = 'iı ' * 100000; // 300.000 karakter
    await tester.enterText(find.byType(TextField).last, big);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('İşleniyor…'), findsOneWidget);

    // compute() gerçek bir isolate kullanır; gerçek zamanlı bekle.
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await tester.pumpAndSettle();
    expect(find.text('İşleniyor…'), findsNothing);
    expect(find.textContaining('önizleme ilk 200000 karakteri'), findsOneWidget);
    expect(find.textContaining('İI İI'), findsOneWidget);
  });
}
