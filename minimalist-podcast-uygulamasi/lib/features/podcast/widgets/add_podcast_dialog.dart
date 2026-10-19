import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../feeds/providers/feeds_provider.dart';

Future<void> showAddPodcastDialog(BuildContext context, WidgetRef ref) async {
  final url = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bgElevated,
      title: const Text('Podcast ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Dinlemek istediğin programın RSS adresini yapıştır. Başlık otomatik alınır.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: url,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Podcast adresi',
              hintText: 'https://ornek.com/feed.xml',
            ),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle')),
      ],
    ),
  );

  if (ok != true || !context.mounted) {
    url.dispose();
    return;
  }

  final trimmed = url.text.trim();
  url.dispose();
  if (trimmed.isEmpty) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
  );

  try {
    await ref.read(feedsProvider.notifier).add('', trimmed);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podcast eklendi — bölümlere göz at')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Podcast eklenemedi: $e')),
      );
    }
  }
}
