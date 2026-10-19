import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/week_utils.dart';
import '../data/planner_repository.dart';
import '../models/plan_models.dart';

final plannerRepositoryProvider = Provider((ref) => PlannerRepository());

final activeWeekStartProvider = StateProvider<DateTime>((ref) {
  return startOfWeek(DateTime.now());
});

final weekPlanProvider =
    AsyncNotifierProvider.family<WeekPlanNotifier, WeekPlan, String>(
  WeekPlanNotifier.new,
);

class WeekPlanNotifier extends FamilyAsyncNotifier<WeekPlan, String> {
  PlannerRepository get _repo => ref.read(plannerRepositoryProvider);

  @override
  Future<WeekPlan> build(String weekStartKey) => _repo.loadWeek(weekStartKey);

  Future<void> assignRecipe(
    int dayIndex,
    MealType meal,
    String? recipeId, {
    int servingsMultiplier = 1,
  }) async {
    final current = state.value ?? WeekPlan.empty(arg);
    final updated = current.withSlot(
      dayIndex,
      meal,
      recipeId,
      servingsMultiplier: servingsMultiplier,
    );
    // Durum kayıttan önce güncellenir: art arda hızlı atamalarda ikinci çağrı
    // eski durumu okuyup ilk atamayı ezmesin.
    state = AsyncData(updated);
    await _repo.saveWeek(updated);
  }
}
