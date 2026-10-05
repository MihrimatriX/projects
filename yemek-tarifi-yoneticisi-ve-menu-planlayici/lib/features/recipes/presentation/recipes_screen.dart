import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/recipe_card.dart';
import '../models/recipe.dart';
import '../providers/recipes_provider.dart';
import 'recipe_form_dialog.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

enum _DurationFilter { all, under30, under60, over60 }

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String? _tagFilter;
  _DurationFilter _duration = _DurationFilter.all;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.slash) return false;
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) return false;
    _searchFocus.requestFocus();
    return true;
  }

  List<Recipe> _filter(List<Recipe> recipes) {
    final q = _search.text.trim().toLowerCase();
    return recipes.where((r) {
      if (_tagFilter != null && !r.tags.contains(_tagFilter)) return false;
      final total = r.totalMinutes;
      switch (_duration) {
        case _DurationFilter.under30:
          if (total == 0 || total > 30) return false;
        case _DurationFilter.under60:
          if (total == 0 || total > 60) return false;
        case _DurationFilter.over60:
          if (total <= 60) return false;
        case _DurationFilter.all:
          break;
      }
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.ingredients.toLowerCase().contains(q) ||
          r.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Set<String> _allTags(List<Recipe> recipes) {
    final tags = <String>{};
    for (final r in recipes) {
      tags.addAll(r.tags);
    }
    return tags;
  }

  Future<void> _addRecipe() async {
    final result = await showRecipeFormDialog(context);
    if (result != null) {
      await ref.read(recipesProvider.notifier).upsert(result.recipe);
    }
  }

  int _columns(double width) {
    if (width >= 1024) return 3;
    if (width >= 600) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      floatingActionButton: YtpFab(onPressed: _addRecipe, label: 'Yeni tarif'),
      body: SafeArea(
        child: recipesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (recipes) {
            final filtered = _filter(recipes);
            final tags = _allTags(recipes).toList()..sort();

            return LayoutBuilder(
              builder: (context, constraints) {
                final cols = _columns(constraints.maxWidth);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  children: [
                    PageHeader(
                      title: 'Tarif Arşivi',
                      subtitle: '${recipes.length} tarif · yerel arşiv',
                      trailing: YtpSearchBar(
                        controller: _search,
                        focusNode: _searchFocus,
                        onChanged: (_) => setState(() {}),
                        onClear: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                    ),
                    YtpFilterPanel(
                      label: 'Süre',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          YtpChip(
                            label: 'Tümü',
                            selected: _duration == _DurationFilter.all,
                            onTap: () => setState(() => _duration = _DurationFilter.all),
                          ),
                          YtpChip(
                            label: '<30 dk',
                            selected: _duration == _DurationFilter.under30,
                            onTap: () => setState(() => _duration = _DurationFilter.under30),
                          ),
                          YtpChip(
                            label: '<60 dk',
                            selected: _duration == _DurationFilter.under60,
                            onTap: () => setState(() => _duration = _DurationFilter.under60),
                          ),
                          YtpChip(
                            label: '>60 dk',
                            selected: _duration == _DurationFilter.over60,
                            onTap: () => setState(() => _duration = _DurationFilter.over60),
                          ),
                        ],
                      ),
                    ),
                    if (tags.isNotEmpty)
                      YtpFilterPanel(
                        label: 'Etiketler',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            YtpChip(
                              label: 'Tümü',
                              selected: _tagFilter == null,
                              onTap: () => setState(() => _tagFilter = null),
                            ),
                            for (final t in tags)
                              YtpChip(
                                label: t,
                                selected: _tagFilter == t,
                                onTap: () => setState(() => _tagFilter = t),
                              ),
                          ],
                        ),
                      ),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text(
                              recipes.isEmpty ? 'Henüz tarif yok' : 'Eşleşen tarif yok',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                            if (recipes.isEmpty) ...[
                              const SizedBox(height: 16),
                              YtpPrimaryButton(label: 'İlk tarifi ekle', icon: Icons.add, onPressed: _addRecipe),
                            ] else ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => setState(() {
                                  _tagFilter = null;
                                  _duration = _DurationFilter.all;
                                  _search.clear();
                                }),
                                child: const Text('Filtreleri temizle'),
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => RecipeCard(
                          recipe: filtered[i],
                          onTap: () => context.push('/recipes/${filtered[i].id}'),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
