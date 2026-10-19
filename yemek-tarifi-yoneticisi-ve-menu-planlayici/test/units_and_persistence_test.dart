import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/core/shopping_merge.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/features/planner/data/planner_repository.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/features/planner/models/plan_models.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/features/planner/providers/planner_provider.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/features/recipes/data/recipes_repository.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/features/recipes/models/recipe.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/features/shopping/data/shopping_repository.dart';
import 'package:yemek_tarifi_yoneticisi_ve_menu_planlayici/features/shopping/providers/shopping_provider.dart';

void main() {
  group('miktar ayristirma', () {
    test('tam+kesir, unicode kesir, ondalik virgul', () {
      expect(parseIngredientLine('1 1/2 su bardağı süt')!.amount, 1.5);
      expect(parseIngredientLine('1½ su bardağı süt')!.amount, 1.5);
      expect(parseIngredientLine('½ çay kaşığı tuz')!.amount, 0.5);
      expect(parseIngredientLine('1,5 kg un')!.amount, 1500);
    });

    test('aralikta ust sinir alinir, birim ayrilir', () {
      final p = parseIngredientLine('2-3 diş sarımsak')!;
      expect((p.amount, p.unit, p.name), (3, 'adet', 'sarımsak'));
    });

    test('"yarım" 0.5 sayilir', () {
      final p = parseIngredientLine('yarım limon')!;
      expect((p.amount, p.name), (0.5, 'limon'));
    });
  });

  group('olcekleme', () {
    test('ad yazildigi gibi kalir, birimsiz satira "adet" eklenmez', () {
      expect(scaleIngredientLines('3 Yumurta\n200 g Un', 2), ['6 Yumurta', '400 g Un']);
    });

    test('kg/l okunur birime doner ve ondalik virgulle yazilir', () {
      expect(scaleIngredientLines('750 g kıyma', 2), ['1,5 kg kıyma']);
      expect(scaleIngredientLines('1 l süt', 0.5), ['500 ml süt']);
      expect(scaleIngredientLines('1/2 çay kaşığı karabiber', 0.5), ['0,25 çk karabiber']);
    });

    test('formatAmount en fazla 2 ondalik', () {
      expect(formatAmount(1 / 3), '0,33');
      expect(formatAmount(2.0), '2');
      expect(formatAmount(1.10), '1,1');
    });
  });

  group('alisveris listesi', () {
    test('kg + g birlesir ve kg olarak gosterilir; farkli birimler ayri kalir', () {
      final merged = mergeIngredientLines(['1 kg un', '500 g un', '2 su bardağı un', 'Tuz', 'tuz']);
      final g = merged.firstWhere((m) => m.unit == 'g');
      expect(g.displayLabel, '1,5 kg un');
      expect(merged.where((m) => m.name == 'un').length, 2);
      expect(merged.firstWhere((m) => m.name == 'tuz').displayLabel, 'tuz');
    });

    test('panoya kopyalanan metin yalnizca alinmamis kalemleri icerir', () {
      final items = mergeIngredientLines(['1 kg un', '2 yumurta']);
      final entries = [
        ShoppingListEntry(item: items[0], inPantry: false),
        ShoppingListEntry(item: items[1], inPantry: true),
      ];
      expect(shoppingListText(entries, {items[0].key}), '- 2 adet yumurta (stokta)');
      expect(shoppingListText(entries, {items[0].key, items[1].key}), isEmpty);
    });
  });

  test('paylasilan tarif olceklenmis malzeme ve porsiyonla yazilir', () {
    const r = Recipe(id: '1', title: 'Kek', ingredients: '200 g un\n2 yumurta', steps: 'Karıştır', servings: 4);
    final text = r.toPrintText(
      ingredientLines: scaleIngredientLines(r.ingredients, 2 / 4),
      servingsOverride: 2,
    );
    expect(text, contains('• 100 g un'));
    expect(text, contains('• 1 yumurta'));
    expect(text, contains('2 porsiyon'));
  });

  group('kalicilik', () {
    test('plan hafta+porsiyon carpaniyla kaydedilip geri okunur', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = PlannerRepository();
      await repo.saveWeek(WeekPlan.empty('2026-10-05').withSlot(2, MealType.dinner, 'r1', servingsMultiplier: 3));
      await repo.saveWeek(WeekPlan.empty('2026-10-12').withSlot(0, MealType.breakfast, 'r2'));
      final w = await repo.loadWeek('2026-10-05');
      expect(w.slotAt(2, MealType.dinner)!.recipeId, 'r1');
      expect(w.slotAt(2, MealType.dinner)!.servingsMultiplier, 3);
      expect((await repo.loadWeek('2026-10-12')).plannedMealCount, 1);
    });

    test('bozuk plan verisi bos hafta doner ve yedeklenir', () async {
      SharedPreferences.setMockInitialValues({PlannerRepository.storageKey: '{bozuk'});
      expect((await PlannerRepository().loadWeek('2026-10-05')).slots, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('${PlannerRepository.storageKey}_bozuk_yedek'), '{bozuk');
    });

    test('okunamayan tarif atlanir, digerleri yuklenir', () async {
      SharedPreferences.setMockInitialValues({
        RecipesRepository.storageKey: jsonEncode([
          {'title': 'id yok'},
          const Recipe(id: 'ok', title: 'Pilav', ingredients: '', steps: '').toJson(),
        ]),
      });
      final list = await RecipesRepository().load();
      expect(list.single.id, 'ok');
    });

    test('bozuk alisveris isaretleri bos doner, sonraki kayit calisir', () async {
      SharedPreferences.setMockInitialValues({ShoppingRepository.storageKey: '[1,2'});
      final repo = ShoppingRepository();
      expect(await repo.loadChecked('w'), isEmpty);
      await repo.saveChecked('w', {'un|g'});
      expect(await repo.loadChecked('w'), {'un|g'});
    });

    test('art arda hizli atamalar birbirini ezmez', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      const key = '2026-10-05';
      await c.read(weekPlanProvider(key).future);
      final n = c.read(weekPlanProvider(key).notifier);
      await Future.wait([
        n.assignRecipe(0, MealType.lunch, 'a'),
        n.assignRecipe(1, MealType.dinner, 'b'),
      ]);
      expect(c.read(weekPlanProvider(key)).value!.plannedMealCount, 2);
      expect((await PlannerRepository().loadWeek(key)).plannedMealCount, 2);
    });
  });
}
