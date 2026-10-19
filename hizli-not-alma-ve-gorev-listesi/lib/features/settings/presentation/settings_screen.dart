import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/backup_service.dart';
import '../../../core/data_reset_service.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/export_service.dart';
import '../../../core/import_service.dart';
import '../../../core/prefs_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../notes/providers/notes_provider.dart';
import '../../projects/providers/projects_provider.dart';
import '../../tags/providers/tags_provider.dart';
import '../../tasks/providers/tasks_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final showCompleted = ref.watch(showCompletedProvider);
    final brightness = Theme.of(context).brightness;

    return ListView(
      padding: const EdgeInsets.all(AppLayout.pagePaddingV),
      children: [
        ListTile(
          leading: Image.asset('assets/icon/app_icon_192.png', width: 40, height: 40),
          title: Text('Akıllı Liste', style: TextStyle(color: AppColors.primaryTextFor(brightness))),
          subtitle: Text(
            'Yerel-first · v1.1.0 · Veriler cihazınızda kalır',
            style: TextStyle(color: AppColors.secondaryTextFor(brightness)),
          ),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Koyu tema'),
          value: themeMode == ThemeMode.dark,
          onChanged: (v) => ref
              .read(themeModeProvider.notifier)
              .set(v ? ThemeMode.dark : ThemeMode.light),
        ),
        SwitchListTile(
          title: const Text('Tamamlanan görevleri göster'),
          value: showCompleted,
          onChanged: (v) => ref.read(showCompletedProvider.notifier).set(v),
        ),
        ListTile(
          title: const Text('Veriyi dışa aktar'),
          subtitle: const Text('JSON panoya kopyala'),
          trailing: const Icon(Icons.copy_outlined),
          onTap: () async {
            await ExportService(ref.read(databaseProvider)).copyToClipboard();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON panoya kopyalandı')),
              );
            }
          },
        ),
        ListTile(
          title: const Text('Veriyi içe aktar'),
          subtitle: const Text('Panodaki JSON (mevcut verinin üzerine yazar)'),
          trailing: const Icon(Icons.download_outlined),
          onTap: () => _importFromClipboard(context, ref),
        ),
        ListTile(
          title: const Text('Dosyaya yedekle'),
          subtitle: const Text('Belgeler\\Akilli Liste Yedekleri (son 20 yedek tutulur)'),
          trailing: const Icon(Icons.save_outlined),
          onTap: () => _backupToFile(context, ref),
        ),
        ListTile(
          title: const Text('Yedekten geri yükle'),
          subtitle: const Text('Otomatik ve elle alınan yedekler'),
          trailing: const Icon(Icons.restore_outlined),
          onTap: () => _restoreFromBackup(context, ref),
        ),
        ListTile(
          title: const Text('Tüm veriyi sil'),
          subtitle: const Text('Silmeden önce otomatik yedek alınır'),
          trailing: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
          onTap: () => _confirmClear(context, ref),
        ),
        const Divider(),
        const ListTile(
          title: Text('Hızlı ekleme'),
          subtitle: Text('#urgent @ev Market al\nTekrar: görev detayından'),
        ),
        const ListTile(
          title: Text('Klavye kısayolları'),
          subtitle: Text('n ekle · Esc kapat'),
        ),
      ],
    );
  }

  Future<void> _importFromClipboard(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Veriyi içe aktar?'),
        content: const Text(
          'Mevcut görevler, projeler ve notların üzerine yazılır. '
          'Yazmadan önce mevcut verinin yedeği alınır.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Devam')),
        ],
      ),
    );
    if (ok != true) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pano boş')),
        );
      }
      return;
    }
    if (context.mounted) await _importText(context, ref, text);
  }

  /// Doğrular, mevcut veriyi yedekler, sonra üzerine yazar.
  Future<void> _importText(BuildContext context, WidgetRef ref, String text) async {
    final db = ref.read(databaseProvider);
    try {
      ImportService.parseBackup(text);
      await BackupService(db).writeBackup(label: 'ice-aktarma-oncesi');
      final result = await ImportService(db).importJson(text);
      _reloadAll(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'İçe aktarıldı: ${result.tasks} görev, ${result.projects} proje, '
              '${result.notes} not, ${result.tags} etiket',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İçe aktarma hatası: ${_message(e)}')),
        );
      }
    }
  }

  static String _message(Object e) => e is FormatException ? e.message : '$e';

  void _reloadAll(WidgetRef ref) {
    ref.invalidate(tasksProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(quickNotesProvider);
    ref.invalidate(tagsProvider);
  }

  Future<void> _backupToFile(BuildContext context, WidgetRef ref) async {
    try {
      final file = await BackupService(ref.read(databaseProvider)).writeBackup();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yedek kaydedildi: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yedek alınamadı: $e')),
        );
      }
    }
  }

  Future<void> _restoreFromBackup(BuildContext context, WidgetRef ref) async {
    final files = await BackupService(ref.read(databaseProvider)).listBackups();
    if (!context.mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Henüz yedek yok. Önce "Dosyaya yedekle" kullanın.')),
      );
      return;
    }
    final chosen = await showDialog<File>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Geri yüklenecek yedek'),
        children: [
          for (final f in files)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, f),
              child: Text(p.basename(f.path)),
            ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedek geri yüklensin mi?'),
        content: Text(
          '${p.basename(chosen.path)}\n\nMevcut veri bu yedekle değiştirilir. '
          'Değiştirmeden önce mevcut verinin de yedeği alınır.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri yükle')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final String text;
    try {
      text = await chosen.readAsString();
    } on FileSystemException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yedek okunamadı: ${e.message}')),
        );
      }
      return;
    }
    if (context.mounted) await _importText(context, ref, text);
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm veriyi sil?'),
        content: const Text(
          'Görevler, projeler, notlar ve etiketler silinir. Önce otomatik yedek '
          'alınır; "Yedekten geri yükle" ile geri getirilebilir.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(databaseProvider);
    final File backup;
    try {
      backup = await BackupService(db).writeBackup(label: 'silme-oncesi');
    } catch (e) {
      // Yedek alınamadıysa veriyi silme.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yedek alınamadığı için silinmedi: $e')),
        );
      }
      return;
    }
    await DataResetService(db).clearAll();
    _reloadAll(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tüm veriler silindi. Yedek: ${p.basename(backup.path)}'),
        ),
      );
    }
  }
}
