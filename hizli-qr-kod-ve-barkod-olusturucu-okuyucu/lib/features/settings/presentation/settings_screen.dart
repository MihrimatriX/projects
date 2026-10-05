import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/file_output.dart';
import '../../../core/history_export.dart';
import '../../../core/history_import.dart';
import '../../../core/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/app_panel.dart';
import '../../qr/providers/qr_history_provider.dart';
import '../../scan/providers/scan_history_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeModeProvider);
    final mode = themeAsync.value ?? AppThemeMode.dark;
    final maskWifi = ref.watch(maskWifiPasswordsProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppPanel(
            title: 'Görünüm',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Tema: ${themeModeLabel(mode)}'),
                const SizedBox(height: 12),
                SegmentedButton<AppThemeMode>(
                  segments: AppThemeMode.values
                      .map((m) => ButtonSegment(
                          value: m, label: Text(themeModeLabel(m))))
                      .toList(),
                  selected: {mode},
                  onSelectionChanged: (set) {
                    ref.read(themeModeProvider.notifier).setMode(set.first);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppPanel(
            title: 'Gizlilik',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wi-Fi şifrelerini maskele'),
              subtitle: const Text('Geçmiş listelerinde şifre gizlenir'),
              value: maskWifi,
              onChanged: (v) =>
                  ref.read(maskWifiPasswordsProvider.notifier).setEnabled(v),
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppPanel(
            title: 'Geçmiş',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dışa aktar (JSON)'),
                  trailing: const Icon(Icons.upload_outlined),
                  onTap: () async {
                    final created = ref.read(qrHistoryProvider).value ?? [];
                    final scanned = ref.read(scanHistoryProvider).value ?? [];
                    await runExport(
                      context,
                      () => HistoryExport.shareJson(
                        title: 'QR geçmişi',
                        created: created,
                        scanned: scanned,
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('İçe aktar (JSON)'),
                  trailing: const Icon(Icons.download_outlined),
                  onTap: () => _importHistory(context, ref),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Oluşturma geçmişini temizle'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () async {
                    if (await _confirm(
                            context, 'Oluşturma geçmişi silinsin mi?') ==
                        true) {
                      await ref.read(qrHistoryProvider.notifier).clear();
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Okuma geçmişini temizle'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () async {
                    if (await _confirm(context, 'Okuma geçmişi silinsin mi?') ==
                        true) {
                      await ref.read(scanHistoryProvider.notifier).clear();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppPanel(
            title: 'Hakkında',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yardım'),
                  trailing: const Icon(Icons.help_outline),
                  onTap: () => context.push('/help'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Sürüm'),
                  subtitle: Text('1.3.0'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gizlilik'),
                  subtitle: Text(
                    'Tüm işlemler cihazınızda yapılır. Veri sunucuya gönderilmez.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importHistory(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) return;

    // Dışa aktarım UTF-8 yazar; Türkçe karakterler bozulmasın diye UTF-8 çözülür.
    final parsed =
        HistoryImport.parseJson(utf8.decode(bytes, allowMalformed: true));
    if (parsed == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçersiz JSON dosyası')),
        );
      }
      return;
    }

    await ref.read(qrHistoryProvider.notifier).replaceAll(parsed.created);
    await ref.read(scanHistoryProvider.notifier).replaceAll(parsed.scanned);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'İçe aktarıldı: ${parsed.created.length} oluşturma, ${parsed.scanned.length} okuma',
          ),
        ),
      );
    }
  }

  Future<bool?> _confirm(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
  }
}
