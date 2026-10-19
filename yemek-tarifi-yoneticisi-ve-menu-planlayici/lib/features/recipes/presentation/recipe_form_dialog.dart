import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';

class RecipeFormResult {
  const RecipeFormResult({required this.recipe, this.isNew = true});

  final Recipe recipe;
  final bool isNew;
}

Future<RecipeFormResult?> showRecipeFormDialog(
  BuildContext context, {
  Recipe? existing,
}) {
  return showDialog<RecipeFormResult>(
    context: context,
    builder: (ctx) => _RecipeFormDialog(existing: existing),
  );
}

class _RecipeFormDialog extends StatefulWidget {
  const _RecipeFormDialog({this.existing});

  final Recipe? existing;

  @override
  State<_RecipeFormDialog> createState() => _RecipeFormDialogState();
}

class _RecipeFormDialogState extends State<_RecipeFormDialog> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _ingredients;
  late final TextEditingController _steps;
  late final TextEditingController _prep;
  late final TextEditingController _cook;
  late final TextEditingController _servings;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _ingredients = TextEditingController(text: e?.ingredients ?? '');
    _steps = TextEditingController(text: e?.steps ?? '');
    _prep = TextEditingController(text: '${e?.prepMinutes ?? 0}');
    _cook = TextEditingController(text: '${e?.cookMinutes ?? 0}');
    _servings = TextEditingController(text: '${e?.servings ?? 2}');
    _tags = TextEditingController(text: e?.tags.join(', ') ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _ingredients.dispose();
    _steps.dispose();
    _prep.dispose();
    _cook.dispose();
    _servings.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarif adı gerekli')),
      );
      return;
    }

    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final recipe = Recipe(
      id: widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: _description.text.trim(),
      ingredients: _ingredients.text.trim(),
      steps: _steps.text.trim(),
      prepMinutes: int.tryParse(_prep.text.trim()) ?? 0,
      cookMinutes: int.tryParse(_cook.text.trim()) ?? 0,
      servings: int.tryParse(_servings.text.trim()) ?? 2,
      tags: tags,
    );

    Navigator.pop(
      context,
      RecipeFormResult(recipe: recipe, isNew: widget.existing == null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Tarifi düzenle' : 'Yeni tarif'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Ad *'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Kısa açıklama'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prep,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Hazırlık (dk)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _cook,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Pişirme (dk)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _servings,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Porsiyon'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: 'Etiketler',
                  hintText: 'vejetaryen, hızlı, çorba',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _ingredients,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Malzemeler',
                  hintText: '200 g un\n2 adet yumurta\n1 sb süt',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _steps,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Adımlar',
                  hintText: 'Her satır bir adım',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(onPressed: _save, child: Text(isEdit ? 'Güncelle' : 'Kaydet')),
      ],
    );
  }
}
