import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/shopping_merge.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/week_utils.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/recipe_card.dart';
import '../../planner/models/plan_models.dart';
import '../../planner/providers/planner_provider.dart';
import '../models/recipe.dart';
import '../providers/recipes_provider.dart';
import 'recipe_form_dialog.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  Future<void> _addToPlanner(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final weekStart = ref.read(activeWeekStartProvider);
    final weekKeyStr = weekKey(weekStart);

    final day = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Plana ekle'),
        children: [
          for (var i = 0; i < 7; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text(dayLabelsTr[i]),
            ),
        ],
      ),
    );
    if (day == null || !context.mounted) return;

    final meal = await showDialog<MealType>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Öğün seç'),
        children: MealType.values
            .map(
              (m) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, m),
                child: Text(m.labelTr),
              ),
            )
            .toList(),
      ),
    );
    if (meal == null || !context.mounted) return;

    await ref.read(weekPlanProvider(weekKeyStr).notifier).assignRecipe(day, meal, recipe.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${recipe.title} plana eklendi')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipesProvider);
    return recipesAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (recipes) {
        Recipe? found;
        for (final r in recipes) {
          if (r.id == recipeId) {
            found = r;
            break;
          }
        }
        if (found == null) {
          return const Scaffold(body: Center(child: Text('Tarif bulunamadı')));
        }
        return _RecipeDetailBody(
          recipe: found,
          onAddToPlan: () => _addToPlanner(context, ref, found!),
        );
      },
    );
  }
}

class _RecipeDetailBody extends ConsumerStatefulWidget {
  const _RecipeDetailBody({required this.recipe, required this.onAddToPlan});

  final Recipe recipe;
  final VoidCallback onAddToPlan;

  @override
  ConsumerState<_RecipeDetailBody> createState() => _RecipeDetailBodyState();
}

class _RecipeDetailBodyState extends ConsumerState<_RecipeDetailBody> {
  late int _scale;

  @override
  void initState() {
    super.initState();
    _scale = widget.recipe.servings;
  }

  void _share() {
    final recipe = widget.recipe;
    // Ölçeklenmiş porsiyonda malzemeler de ölçeklenmiş paylaşılır (eskiden yalnızca
    // "(Porsiyon: X kişi)" notu ekleniyor, miktarlar orijinal kalıyordu).
    final text = _scale == recipe.servings || recipe.servings <= 0
        ? recipe.toPrintText()
        : recipe.toPrintText(
            ingredientLines: scaleIngredientLines(recipe.ingredients, _scale / recipe.servings),
            servingsOverride: _scale,
          );
    SharePlus.instance.share(ShareParams(text: text, subject: recipe.title));
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    // Kesirli oran: 4 kişilik tarif 2 kişiye 0.5, 6 kişiye 1.5 ile çarpılır
    // (eskiden tam sayıya yuvarlanıyor, küçültme hiç çalışmıyordu).
    final multiplier = recipe.servings > 0 ? _scale / recipe.servings : 1;
    final scaledIngredients = scaleIngredientLines(recipe.ingredients, multiplier);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final initial = recipe.title.isNotEmpty ? recipe.title[0].toUpperCase() : '?';
    final steps = recipe.steps.split('\n').where((l) => l.trim().isNotEmpty).toList();

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          children: [
            PageHeader(
              title: recipe.title,
              leading: TextButton.icon(
                onPressed: () => context.go('/recipes'),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Tariflere dön'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: EdgeInsets.zero,
                ),
              ),
              trailing: PortionScaler(
                value: _scale,
                min: 1,
                max: 24,
                onChanged: (v) => setState(() => _scale = v),
              ),
            ),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _mainColumn(recipe, initial, steps)),
                  const SizedBox(width: 32),
                  SizedBox(width: 380, child: _sideColumn(recipe, scaledIngredients)),
                ],
              )
            else ...[
              _mainColumn(recipe, initial, steps),
              const SizedBox(height: 24),
              _sideColumn(recipe, scaledIngredients),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mainColumn(Recipe recipe, String initial, List<String> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipeHero(initial: initial),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (recipe.totalMinutes > 0) MetaChip(icon: Icons.schedule, label: '${recipe.totalMinutes} dk'),
            MetaChip(icon: Icons.group_outlined, label: '$_scale kişi'),
            for (final t in recipe.tags) MetaChip(icon: Icons.label_outline, label: t),
          ],
        ),
        if (recipe.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(recipe.description, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
        const SizedBox(height: 24),
        DetailPanel(
          title: 'Hazırlanış',
          child: Column(
            children: [
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AppColors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(steps[i].trim(), style: const TextStyle(fontSize: 14, height: 1.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideColumn(Recipe recipe, List<String> scaledIngredients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailPanel(
          title: 'Malzemeler',
          child: Column(
            children: [
              for (final line in scaledIngredients)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(line, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            YtpPrimaryButton(label: 'Plana ekle', icon: Icons.calendar_month, onPressed: widget.onAddToPlan),
            YtpSecondaryButton(label: 'Paylaş', icon: Icons.share, onPressed: _share),
            YtpSecondaryButton(
              label: 'Düzenle',
              icon: Icons.edit_outlined,
              onPressed: () async {
                final result = await showRecipeFormDialog(context, existing: recipe);
                if (result != null) {
                  await ref.read(recipesProvider.notifier).upsert(result.recipe);
                }
              },
            ),
            IconButton(
              tooltip: 'Sil',
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Tarifi sil'),
                    content: Text('${recipe.title} silinsin mi?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
                    ],
                  ),
                );
                if (ok == true && mounted) {
                  await ref.read(recipesProvider.notifier).remove(recipe.id);
                  if (mounted) context.go('/recipes');
                }
              },
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            ),
          ],
        ),
      ],
    );
  }
}
