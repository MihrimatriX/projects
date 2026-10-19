import 'package:shared_preferences/shared_preferences.dart';

import '../features/pantry/data/pantry_repository.dart';
import '../features/planner/data/planner_repository.dart';
import '../features/recipes/data/recipes_repository.dart';
import '../features/shopping/data/shopping_repository.dart';

/// Tüm uygulama verisini siler.
Future<void> clearAllAppData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(RecipesRepository.storageKey);
  await prefs.remove(PlannerRepository.storageKey);
  await prefs.remove(ShoppingRepository.storageKey);
  await prefs.remove(PantryRepository.storageKey);
  await prefs.remove('shopping_checked_v1');
  await prefs.remove('theme_mode_v1');
  await prefs.remove('seed_done_v1');
}
