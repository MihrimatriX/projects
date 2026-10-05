import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data_reset.dart';
import '../../../core/import/recipe_import.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/recipe_card.dart';
import '../../pantry/providers/pantry_provider.dart';
import '../../planner/providers/planner_provider.dart';
import '../../recipes/providers/recipes_provider.dart';
import '../../shopping/providers/shopping_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final json = await ref.read(recipesProvider.notifier).exportJson();
    if (!context.mounted) return;
    await SharePlus.instance.share(ShareParams(text: json, subject: 'yemek-planlayici-yedek.json'));
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('JSON içe aktar'),
        content: TextField(
          controller: controller,
          maxLines: 12,
          decoration: const InputDecoration(
            hintText: 'Dışa aktarılan JSON dizisini yapıştırın',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İçe aktar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      controller.dispose();
      return;
    }
    final result = parseRecipesJson(controller.text);
    controller.dispose();
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errors.join('\n'))));
      return;
    }
    final n = await ref.read(recipesProvider.notifier).importRecipes(result.recipes);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n tarif içe aktarıldı')));
  }

  Future<void> _importMarkdown(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Markdown içe aktar'),
        content: TextField(
          controller: controller,
          maxLines: 14,
          decoration: const InputDecoration(
            hintText: '# Başlık\n## Malzemeler\n...\n## Adımlar\n...',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İçe aktar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      controller.dispose();
      return;
    }
    final result = parseRecipeMarkdown(controller.text);
    controller.dispose();
    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errors.join('\n'))));
      return;
    }
    final n = await ref.read(recipesProvider.notifier).importRecipes(result.recipes);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n tarif içe aktarıldı')));
  }

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm veriyi sil'),
        content: const Text('Tarifler, planlar, kiler ve alışveriş işaretleri silinir. Geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await clearAllAppData();
    ref.invalidate(recipesProvider);
    ref.invalidate(pantryProvider);
    ref.invalidate(themeModeProvider);
    // Tüm haftalar: yalnızca aktif hafta yenilenirse önceden açılmış haftalar eski planı gösteriyordu.
    ref.invalidate(weekPlanProvider);
    ref.invalidate(shoppingCheckedProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veriler silindi')));
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
          children: [
            const PageHeader(title: 'Ayarlar', subtitle: 'Veri içe/dışa aktarma'),
            DetailPanel(
              title: 'Dışa aktar',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tarifleri JSON olarak paylaşın veya kaydedin.',
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  YtpPrimaryButton(label: 'JSON paylaş', icon: Icons.download, onPressed: () => _exportJson(context, ref)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DetailPanel(
              title: 'İçe aktar',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  YtpSecondaryButton(label: 'JSON içe aktar', icon: Icons.upload, onPressed: () => _importJson(context, ref)),
                  const SizedBox(height: 10),
                  YtpSecondaryButton(label: 'Markdown içe aktar', icon: Icons.description, onPressed: () => _importMarkdown(context, ref)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DetailPanel(
              title: 'Görünüm',
              child: themeAsync.when(
                loading: () => const Text('Tema yükleniyor…'),
                error: (_, __) => const SizedBox.shrink(),
                data: (mode) => DropdownButtonFormField<AppThemeMode>(
                  initialValue: mode,
                  decoration: const InputDecoration(labelText: 'Tema'),
                  items: AppThemeMode.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(themeModeLabel(m))))
                      .toList(),
                  onChanged: (m) {
                    if (m != null) ref.read(themeModeProvider.notifier).setMode(m);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            const DetailPanel(
              title: 'Hakkında',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sürüm: 1.2.0', style: TextStyle(fontSize: 14)),
                  SizedBox(height: 8),
                  Text('Dil: Türkçe', style: TextStyle(fontSize: 14)),
                  SizedBox(height: 8),
                  Text('Tüm veriler yalnızca bu cihazda saklanır.', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  SizedBox(height: 8),
                  Text('Web: Chrome → Uygulamayı yükle (PWA)', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            YtpSecondaryButton(
              label: 'Tüm veriyi sil',
              icon: Icons.delete_forever,
              onPressed: () => _confirmClearData(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
