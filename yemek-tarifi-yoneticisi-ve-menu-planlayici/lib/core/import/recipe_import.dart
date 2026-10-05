import 'dart:convert';

import '../../features/recipes/models/recipe.dart';

class ImportResult {
  const ImportResult({required this.recipes, this.errors = const []});

  final List<Recipe> recipes;
  final List<String> errors;

  bool get ok => recipes.isNotEmpty;
}

ImportResult parseRecipesJson(String raw) {
  final errors = <String>[];
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! List) {
      return const ImportResult(recipes: [], errors: ['JSON bir dizi olmalı']);
    }
    final recipes = <Recipe>[];
    for (var i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map<String, dynamic>) {
        errors.add('Satır ${i + 1}: geçersiz nesne');
        continue;
      }
      try {
        var recipe = Recipe.fromJson(item);
        if (recipe.id.isEmpty) {
          recipe = Recipe(
            id: '${DateTime.now().millisecondsSinceEpoch}_$i',
            title: recipe.title,
            description: recipe.description,
            ingredients: recipe.ingredients,
            steps: recipe.steps,
            prepMinutes: recipe.prepMinutes,
            cookMinutes: recipe.cookMinutes,
            servings: recipe.servings,
            tags: recipe.tags,
          );
        }
        recipes.add(recipe);
      } catch (e) {
        errors.add('Satır ${i + 1}: $e');
      }
    }
    return ImportResult(recipes: recipes, errors: errors);
  } catch (e) {
    return ImportResult(recipes: [], errors: ['JSON ayrıştırma: $e']);
  }
}

ImportResult parseRecipeMarkdown(String raw) {
  final lines = raw.split('\n');
  String title = 'İçe aktarılan tarif';
  final desc = <String>[];
  final ingredients = <String>[];
  final steps = <String>[];
  var section = '';

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.startsWith('# ')) {
      title = trimmed.substring(2).trim();
      section = '';
      continue;
    }
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('## ')) {
      final h = lower.substring(3);
      if (h.contains('malzeme')) {
        section = 'ingredients';
      } else if (h.contains('adım') || h.contains('yapılış') || h.contains('hazırlan')) {
        section = 'steps';
      } else if (h.contains('açıklama') || h.contains('not')) {
        section = 'desc';
      } else {
        section = '';
      }
      continue;
    }
    if (trimmed.isEmpty) continue;

    switch (section) {
      case 'ingredients':
        ingredients.add(trimmed.replaceFirst(RegExp(r'^[-•*]\s*'), ''));
      case 'steps':
        steps.add(trimmed.replaceFirst(RegExp(r'^[-•*\d.]+\s*'), ''));
      case 'desc':
        desc.add(trimmed);
      default:
        if (ingredients.isEmpty && steps.isEmpty && !trimmed.startsWith('#')) {
          desc.add(trimmed);
        }
    }
  }

  if (ingredients.isEmpty && steps.isEmpty) {
    return const ImportResult(
      recipes: [],
      errors: ['Markdown: ## Malzemeler ve ## Adımlar bölümleri gerekli'],
    );
  }

  final recipe = Recipe(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    title: title,
    description: desc.join('\n'),
    ingredients: ingredients.join('\n'),
    steps: steps.join('\n'),
  );
  return ImportResult(recipes: [recipe]);
}
