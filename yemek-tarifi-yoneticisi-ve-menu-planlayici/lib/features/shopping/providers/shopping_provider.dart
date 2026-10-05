import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shopping_merge.dart';
import '../../pantry/providers/pantry_provider.dart';
import '../../planner/providers/planner_provider.dart';
import '../../recipes/providers/recipes_provider.dart';
import '../data/shopping_repository.dart';

final shoppingRepositoryProvider = Provider((ref) => ShoppingRepository());

final shoppingCheckedProvider =
    AsyncNotifierProvider.family<ShoppingCheckedNotifier, Set<String>, String>(
  ShoppingCheckedNotifier.new,
);

class ShoppingCheckedNotifier extends FamilyAsyncNotifier<Set<String>, String> {
  ShoppingRepository get _repo => ref.read(shoppingRepositoryProvider);

  @override
  Future<Set<String>> build(String weekStartKey) =>
      _repo.loadChecked(weekStartKey);

  Future<void> toggle(String itemKey, bool checked) async {
    final current = {...(state.value ?? {})};
    if (checked) {
      current.add(itemKey);
    } else {
      current.remove(itemKey);
    }
    await _repo.saveChecked(arg, current);
    state = AsyncData(current);
  }

  Future<void> clearAll() async {
    await _repo.saveChecked(arg, {});
    state = const AsyncData({});
  }
}

final mergedShoppingListProvider =
    Provider.family<List<MergedIngredient>, String>((ref, weekStartKey) {
  final plan = ref.watch(weekPlanProvider(weekStartKey)).value;
  final recipes = ref.watch(recipesProvider).value ?? [];
  if (plan == null) return [];

  final recipeMap = {for (final r in recipes) r.id: r};
  final lines = <String>[];

  for (final planned in plan.plannedRecipes) {
    final recipe = recipeMap[planned.recipeId];
    if (recipe == null) continue;
    lines.addAll(
      scaleIngredientLines(recipe.ingredients, planned.servingsMultiplier),
    );
  }

  return mergeIngredientLines(lines);
});

final hidePantryItemsProvider = StateProvider<bool>((ref) => false);

class ShoppingListEntry {
  const ShoppingListEntry({required this.item, required this.inPantry});

  final MergedIngredient item;
  final bool inPantry;
}

final shoppingEntriesProvider =
    Provider.family<List<ShoppingListEntry>, String>((ref, weekStartKey) {
  final items = ref.watch(mergedShoppingListProvider(weekStartKey));
  final pantry = ref.watch(pantryProvider).value ?? {};
  return items
      .map((i) => ShoppingListEntry(
            item: i,
            inPantry: isMergedItemInPantry(i, pantry),
          ))
      .toList();
});

/// Panoya kopyalanacak düz metin liste: yalnızca henüz alınmamış (işaretsiz) kalemler.
String shoppingListText(List<ShoppingListEntry> visible, Set<String> checked) => visible
    .where((e) => !checked.contains(e.item.key))
    .map((e) => '- ${e.item.displayLabel}${e.inPantry ? ' (stokta)' : ''}')
    .join('\n');
