import 'package:flutter_test/flutter_test.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/core/shopping_merge.dart';

void main() {
  test('malzeme satırları çarpan ile ölçeklenir', () {
    final scaled = scaleIngredientLines('200 g un\n2 adet yumurta', 2);
    expect(scaled.first, contains('400'));
    expect(scaled.last, contains('4'));
  });

  test('porsiyon küçültme kesirli çarpanla çalışır', () {
    expect(scaleIngredientLines('200 g un', 0.5), ['100 g un']);
  });
}
