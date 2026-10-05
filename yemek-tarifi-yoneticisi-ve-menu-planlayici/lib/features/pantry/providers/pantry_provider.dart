import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shopping_merge.dart';
import '../data/pantry_repository.dart';

final pantryRepositoryProvider = Provider((ref) => PantryRepository());

final pantryProvider =
    AsyncNotifierProvider<PantryNotifier, Set<String>>(PantryNotifier.new);

class PantryNotifier extends AsyncNotifier<Set<String>> {
  PantryRepository get _repo => ref.read(pantryRepositoryProvider);

  @override
  Future<Set<String>> build() => _repo.load();

  Future<void> add(String name) async {
    final key = _normalize(name);
    if (key.isEmpty) return;
    final current = {...(state.value ?? {})}..add(key);
    await _repo.save(current);
    state = AsyncData(current);
  }

  Future<void> remove(String key) async {
    final current = {...(state.value ?? {})}..remove(key);
    await _repo.save(current);
    state = AsyncData(current);
  }

  Future<void> toggleFromIngredientName(String displayName) async {
    final key = _normalize(displayName);
    final current = state.value ?? {};
    if (current.contains(key)) {
      await remove(key);
    } else {
      await add(displayName);
    }
  }
}

String _normalize(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool isIngredientInPantry(String ingredientName, Set<String> pantry) {
  if (pantry.isEmpty) return false;
  final name = ingredientName.toLowerCase();
  for (final item in pantry) {
    if (name == item || name.contains(item) || item.contains(name)) {
      return true;
    }
  }
  return false;
}

bool isMergedItemInPantry(MergedIngredient item, Set<String> pantry) =>
    isIngredientInPantry(item.name, pantry);
