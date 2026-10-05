import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takvim_ve_zamanlayici/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hafta grid ekrani yuklenir', (WidgetTester tester) async {
    await bootstrap();
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Odak Zamanlayıcı'), findsOneWidget);
    expect(find.text('Etkinlik'), findsWidgets);
  });
}
