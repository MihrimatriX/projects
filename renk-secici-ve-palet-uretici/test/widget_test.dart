import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renk_secici_ve_palet_uretici/app.dart';

void main() {
  testWidgets('masaustu ekran yuklenir', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PaletteApp());
    await tester.pumpAndSettle();
    expect(find.text('Tamamlayıcı'), findsOneWidget);
  });

  testWidgets('mobil ekran yuklenir', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PaletteApp());
    await tester.pumpAndSettle();
    expect(find.text('Geçmiş'), findsOneWidget);
    expect(find.textContaining('RENK'), findsWidgets);
  });
}
