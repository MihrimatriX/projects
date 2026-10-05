import 'package:flutter_test/flutter_test.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/core/shopping_merge.dart';

void main() {
  test('aynı malzeme ve birim birleşir', () {
    final merged = mergeIngredientLines([
      '200 g un',
      '300 g un',
      '2 adet yumurta',
    ]);
    expect(merged.length, 2);
    final flour = merged.firstWhere((m) => m.name == 'un');
    expect(flour.amount, 500);
    expect(flour.unit, 'g');
  });

  test('birimsiz ve miktarsız satırlar bozulmaz', () {
    final egg = parseIngredientLine('3 yumurta')!;
    expect((egg.amount, egg.unit, egg.name), (3, 'adet', 'yumurta'));
    final flour = parseIngredientLine('2 su bardağı un')!;
    expect((flour.amount, flour.unit, flour.name), (2, 'sb', 'un'));
    expect(parseIngredientLine('1/2 çay kaşığı karabiber')!.amount, 0.5);
    expect(scaleIngredientLines('Tuz', 2), ['Tuz']);
  });

  test('kg gram birimine normalize edilir', () {
    final merged = mergeIngredientLines(['1 kg patates', '500 g patates']);
    expect(merged.length, 1);
    expect(merged.first.amount, 1500);
    expect(merged.first.unit, 'g');
  });
}
