import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/app.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('ana ekran yüklenir', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();
    expect(find.text('Yemek Tarifi Yöneticisi'), findsOneWidget);
    expect(find.text('Tarif Arşivi'), findsOneWidget);
    expect(find.text('Haftalık Planlayıcı'), findsOneWidget);
  });
}
