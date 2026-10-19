import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/app.dart';

void main() {
  testWidgets('uygulama yuklenir ve alt navigasyon gorunur', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('QR Kod & Barkod'), findsOneWidget);
    expect(find.text('Oluştur'), findsWidgets);
    expect(find.text('Oku'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
