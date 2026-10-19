import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/seed/sample_recipes.dart';
import '../data/recipes_repository.dart';
import '../models/recipe.dart';

final recipesRepositoryProvider = Provider((ref) => RecipesRepository());

final recipesProvider =
    AsyncNotifierProvider<RecipesNotifier, List<Recipe>>(RecipesNotifier.new);

class RecipesNotifier extends AsyncNotifier<List<Recipe>> {
  RecipesRepository get _repo => ref.read(recipesRepositoryProvider);

  @override
  Future<List<Recipe>> build() async {
    var list = await _repo.load();
    if (list.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool('seed_done_v1') ?? false)) {
        list = sampleRecipes();
        await _repo.save(list);
        await prefs.setBool('seed_done_v1', true);
      }
    }
    return list;
  }

  Future<void> upsert(Recipe recipe) async {
    final current = state.value ?? [];
    final idx = current.indexWhere((r) => r.id == recipe.id);
    final updated = [...current];
    if (idx >= 0) {
      updated[idx] = recipe;
    } else {
      updated.add(recipe);
    }
    await _repo.save(updated);
    state = AsyncData(updated);
  }

  Future<int> importRecipes(List<Recipe> incoming, {bool merge = true}) async {
    final current = merge ? (state.value ?? []) : <Recipe>[];
    final byId = {for (final r in current) r.id: r};
    var added = 0;
    for (final r in incoming) {
      final id = byId.containsKey(r.id)
          ? '${DateTime.now().millisecondsSinceEpoch}_$added'
          : r.id;
      final recipe = Recipe(
        id: id,
        title: r.title,
        description: r.description,
        ingredients: r.ingredients,
        steps: r.steps,
        prepMinutes: r.prepMinutes,
        cookMinutes: r.cookMinutes,
        servings: r.servings,
        tags: r.tags,
      );
      byId[recipe.id] = recipe;
      added++;
    }
    final updated = byId.values.toList();
    await _repo.save(updated);
    state = AsyncData(updated);
    return added;
  }

  Future<void> remove(String id) async {
    final current = state.value ?? [];
    final updated = current.where((r) => r.id != id).toList();
    await _repo.save(updated);
    state = AsyncData(updated);
  }

  Recipe? byId(String id) {
    final list = state.value;
    if (list == null) return null;
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<String> exportJson() async {
    final list = state.value ?? [];
    return const JsonEncoder.withIndent('  ')
        .convert(list.map((r) => r.toJson()).toList());
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.load());
  }
}
