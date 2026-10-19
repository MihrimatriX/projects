import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/safe_json.dart';

import '../models/recipe.dart';

class RecipesRepository {
  static const storageKey = 'recipes_v1';
  static const _key = storageKey;

  Future<List<Recipe>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = await decodeStoredJson<List<dynamic>>(prefs, _key, raw);
    if (list == null) return [];
    final recipes = <Recipe>[];
    for (final e in list) {
      try {
        recipes.add(Recipe.fromJson(e as Map<String, dynamic>));
      } catch (_) {
        // Okunamayan tarif atlanir; ham veri yedeklenir ki kaybolmasin.
        await prefs.setString('${_key}_bozuk_yedek', raw);
      }
    }
    return recipes;
  }

  Future<void> save(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(recipes.map((r) => r.toJson()).toList()),
    );
  }
}
