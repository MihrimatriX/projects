import 'package:flutter_test/flutter_test.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/core/import/recipe_import.dart';

void main() {
  test('markdown tarif ayrıştırır', () {
    const md = '''
# Menemen

## Malzemeler
2 adet yumurta
1 adet domates

## Adımlar
Yumurtaları çırpın
Domatesi ekleyin
''';
    final result = parseRecipeMarkdown(md);
    expect(result.ok, isTrue);
    expect(result.recipes.first.title, 'Menemen');
    expect(result.recipes.first.ingredients, contains('yumurta'));
    expect(result.recipes.first.steps, contains('çırpın'));
  });

  test('json dizi ayrıştırır', () {
    const json = '''
[{"id":"a","title":"Test","ingredients":"1 g tuz","steps":"Karıştır"}]
''';
    final result = parseRecipesJson(json);
    expect(result.ok, isTrue);
    expect(result.recipes.first.title, 'Test');
  });
}
