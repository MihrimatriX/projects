import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/week_utils.dart';
import '../../../core/widgets/page_header.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/providers/recipes_provider.dart';
import '../models/plan_models.dart';
import '../providers/planner_provider.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  Future<void> _pickRecipe(
    BuildContext context,
    WidgetRef ref,
    String weekKeyStr,
    int dayIndex,
    MealType meal,
  ) async {
    final recipes = ref.read(recipesProvider).value ?? [];
    if (recipes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir tarif ekleyin')),
      );
      return;
    }

    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${dayLabelsTr[dayIndex]} · ${meal.labelTr}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Boşalt'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: recipes.length,
                itemBuilder: (_, i) {
                  final r = recipes[i];
                  return ListTile(
                    title: Text(r.title),
                    subtitle: r.totalMinutes > 0 ? Text('${r.totalMinutes} dk') : null,
                    onTap: () => Navigator.pop(ctx, r.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    if (selected.isEmpty) {
      await ref.read(weekPlanProvider(weekKeyStr).notifier).assignRecipe(dayIndex, meal, null);
      return;
    }
    if (!context.mounted) return;

    final multiplier = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Porsiyon çarpanı'),
        content: const Text('Meal prep için malzeme miktarını katlayın.'),
        actions: [
          for (final m in [1, 2, 3, 4])
            TextButton(
              onPressed: () => Navigator.pop(ctx, m),
              child: Text(m == 1 ? '1× (normal)' : '$m×'),
            ),
        ],
      ),
    );
    if (multiplier == null) return;

    await ref.read(weekPlanProvider(weekKeyStr).notifier).assignRecipe(
          dayIndex,
          meal,
          selected,
          servingsMultiplier: multiplier,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStart = ref.watch(activeWeekStartProvider);
    final weekKeyStr = weekKey(weekStart);
    final planAsync = ref.watch(weekPlanProvider(weekKeyStr));
    final recipes = ref.watch(recipesProvider).value ?? [];
    final recipeMap = {for (final r in recipes) r.id: r};
    final today = DateTime.now();
    final days = weekDays(weekStart);
    final mealCount = planAsync.value?.plannedMealCount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: planAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (plan) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
              children: [
                PageHeader(
                  title: 'Haftalık Planlayıcı',
                  subtitle: '7×3 öğün grid',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [BoxShadow(color: Color(0x141C1917), blurRadius: 24, offset: Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DURUM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.08)),
                        Text('$mealCount öğün', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(formatWeekRange(weekStart), style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          // Takvim günüyle kaydır: ±7×24 saat yaz saati geçişinde Pazar'a
                          // düşüp yanlış hafta anahtarı (weekKey) üretiyordu.
                          ref.read(activeWeekStartProvider.notifier).state =
                              DateTime(weekStart.year, weekStart.month, weekStart.day - 7);
                        },
                      ),
                      SizedBox(
                        width: 180,
                        child: Text(
                          formatWeekRange(weekStart),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          ref.read(activeWeekStartProvider.notifier).state =
                              DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          ref.read(activeWeekStartProvider.notifier).state = startOfWeek(DateTime.now());
                        },
                        child: const Text('Bu hafta'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => context.go('/shopping'),
                        icon: const Icon(Icons.shopping_basket_outlined, size: 18),
                        label: const Text('Alışveriş'),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _PlannerGrid(
                    plan: plan,
                    days: days,
                    today: today,
                    recipeMap: recipeMap,
                    onCellTap: (day, meal) => _pickRecipe(context, ref, weekKeyStr, day, meal),
                    onClear: (day, meal) =>
                        ref.read(weekPlanProvider(weekKeyStr).notifier).assignRecipe(day, meal, null),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Boş bir öğün hücresine dokunarak tarif atayın. Meal prep için porsiyon çarpanı seçebilirsiniz.',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlannerGrid extends StatelessWidget {
  const _PlannerGrid({
    required this.plan,
    required this.days,
    required this.today,
    required this.recipeMap,
    required this.onCellTap,
    required this.onClear,
  });

  final WeekPlan plan;
  final List<DateTime> days;
  final DateTime today;
  final Map<String, Recipe> recipeMap;
  final void Function(int day, MealType meal) onCellTap;
  final void Function(int day, MealType meal) onClear;

  @override
  Widget build(BuildContext context) {
    const mealLabelWidth = 80.0;
    const cellMin = 120.0;
    const gap = 10.0;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(cellMin),
      columnWidths: const {0: FixedColumnWidth(mealLabelWidth)},
      children: [
        TableRow(
          children: [
            const SizedBox(),
            for (var d = 0; d < 7; d++)
              _HeaderCell(
                label: dayLabelsTr[d],
                today: isSameDay(days[d], today),
              ),
          ],
        ),
        for (final meal in MealType.values)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 12, bottom: 12),
                child: Text(
                  meal.labelTr.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.06),
                ),
              ),
              for (var day = 0; day < 7; day++)
                Padding(
                  padding: const EdgeInsets.all(gap / 2),
                  child: _MealSlot(
                    isToday: isSameDay(days[day], today),
                    slot: plan.slotAt(day, meal),
                    title: () {
                      final slot = plan.slotAt(day, meal);
                      final id = slot?.recipeId;
                      if (id == null) return null;
                      final t = recipeMap[id]?.title ?? 'Silinmiş tarif';
                      final mult = slot!.servingsMultiplier;
                      return mult > 1 ? '$t ($mult×)' : t;
                    }(),
                    onTap: () => onCellTap(day, meal),
                    onClear: () => onClear(day, meal),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.today});

  final String label;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: today ? AppColors.accentSoft : Color.alphaBlend(const Color(0x3DF3EDE6), AppColors.bgSurface),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: today ? AppColors.accent.withValues(alpha: 0.28) : AppColors.border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: today ? AppColors.accent : AppColors.textMuted,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}

class _MealSlot extends StatelessWidget {
  const _MealSlot({
    required this.isToday,
    required this.slot,
    required this.title,
    required this.onTap,
    required this.onClear,
  });

  final bool isToday;
  final MealSlot? slot;
  final String? title;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final filled = title != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 120, minHeight: 104),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: filled ? AppColors.border : AppColors.borderStrong,
                  width: filled ? 1 : 1.5,
                ),
                color: filled ? AppColors.bgHover : AppColors.bgSurface,
              ),
              child: filled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title!,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (slot != null && slot!.servingsMultiplier > 1)
                          Text(
                            '${slot!.servingsMultiplier}× porsiyon',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                            onPressed: onClear,
                            icon: const Icon(Icons.close, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text('Tarif seç', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
            ),
            if (isToday)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
