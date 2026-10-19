import 'dart:convert';



import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/platform/platform_info.dart';

import '../../../core/settings/app_settings.dart';

import '../../../core/theme/app_theme.dart';

import '../../feeds/providers/feeds_provider.dart';

import '../../feeds/services/feed_refresh_service.dart';

import '../../feeds/services/opml_sync_provider.dart';

import '../../feeds/utils/opml_service.dart';



class SettingsScreen extends ConsumerWidget {

  const SettingsScreen({super.key});



  Future<void> _editCorsProxy(BuildContext context, WidgetRef ref) async {

    final current = ref.read(appSettingsProvider).value?.corsProxyBase ?? '';

    final controller = TextEditingController(text: current);

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        backgroundColor: AppColors.bgElevated,

        title: const Text('Ağ proxy (gelişmiş)'),

        content: TextField(

          controller: controller,

          decoration: const InputDecoration(

            hintText: 'http://localhost:8766/proxy?url=',

            helperText: 'Web sürümünde feed yüklenmezse run.ps1 ile başlatılan yerel proxy kullanılır.',

          ),

        ),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),

          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),

        ],

      ),

    );

    if (ok == true) {

      await ref.read(appSettingsProvider.notifier).setCorsProxyBase(controller.text);

    }

    controller.dispose();

  }



  Future<void> _exportOpmlToFile(BuildContext context, WidgetRef ref) async {

    final feeds = ref.read(feedsProvider).value ?? [];

    final xml = exportOpml(feeds);

    final path = await FilePicker.platform.saveFile(

      dialogTitle: 'OPML kaydet',

      fileName: 'podcastler.opml',

      type: FileType.custom,

      allowedExtensions: ['opml'],

      bytes: Uint8List.fromList(utf8.encode(xml)),

    );

    if (context.mounted && path != null) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Kaydedildi: $path')),

      );

    }

  }



  Future<void> _configureOpmlFolder(BuildContext context, WidgetRef ref) async {

    final sync = ref.read(opmlSyncServiceProvider);

    final path = await sync.pickFolder();

    if (path == null) return;

    await ref.read(feedsProvider.notifier).configureOpmlSyncFolder(path);

    if (context.mounted) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('OPML klasörü: $path')),

      );

    }

  }



  Future<void> _exportOpml(BuildContext context, WidgetRef ref) async {

    final feeds = ref.read(feedsProvider).value ?? [];

    final xml = exportOpml(feeds);

    await showDialog<void>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Podcast listesini dışa aktar'),

        content: SizedBox(

          width: 400,

          child: SingleChildScrollView(child: SelectableText(xml)),

        ),

        actions: [

          TextButton(

            onPressed: () {

              Clipboard.setData(ClipboardData(text: xml));

              ScaffoldMessenger.of(context).showSnackBar(

                const SnackBar(content: Text('Panoya kopyalandı')),

              );

            },

            child: const Text('Kopyala'),

          ),

          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),

        ],

      ),

    );

  }



  Future<void> _importOpml(BuildContext context, WidgetRef ref) async {

    final controller = TextEditingController();

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Podcast listesini içe aktar'),

        content: TextField(

          controller: controller,

          maxLines: 12,

          decoration: const InputDecoration(

            hintText: 'OPML içeriğini yapıştır',

            border: OutlineInputBorder(),

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

    try {

      final count = await ref.read(feedsProvider.notifier).importOpml(controller.text);

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(count > 0 ? '$count podcast eklendi' : 'Yeni podcast yok')),

        );

      }

    } catch (e) {

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('İçe aktarılamadı: $e')),

        );

      }

    }

    controller.dispose();

  }



  Future<void> _importOpmlFromFile(BuildContext context, WidgetRef ref) async {

    final result = await FilePicker.platform.pickFiles(

      type: FileType.custom,

      allowedExtensions: ['opml', 'xml'],

      withData: true,

    );

    if (result == null || result.files.isEmpty || !context.mounted) return;



    final file = result.files.first;

    final bytes = file.bytes;

    if (bytes == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Dosya okunamadı')),

      );

      return;

    }



    try {

      final xml = utf8.decode(bytes, allowMalformed: true);

      final count = await ref.read(feedsProvider.notifier).importOpml(xml);

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(count > 0 ? '$count podcast eklendi' : 'Yeni podcast yok')),

        );

      }

    } catch (e) {

      if (context.mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('İçe aktarılamadı: $e')),

        );

      }

    }

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final settings = ref.watch(appSettingsProvider);



    return Scaffold(

      appBar: AppBar(title: const Text('Ayarlar')),

      body: ListView(

        children: [

          const _SectionHeader('Dinleme'),

          settings.when(

            loading: () => const LinearProgressIndicator(),

            error: (e, _) => ListTile(title: Text('Ayarlar yüklenemedi: $e')),

            data: (s) => Column(

              children: [

                SwitchListTile(

                  title: const Text('Smart Speed'),

                  subtitle: const Text('Sessizlikleri kısaltır, konuşmayı hızlandırır'),

                  value: s.smartSpeedEnabled,

                  onChanged: (v) => ref.read(appSettingsProvider.notifier).setSmartSpeed(v),

                ),

                if (PlatformInfo.supportsOfflineDownload)

                  SwitchListTile(

                    title: const Text('Yalnızca Wi-Fi ile indir'),

                    subtitle: const Text('Mobil veri kullanılmaz'),

                    value: s.wifiOnlyDownloads,

                    onChanged: (v) => ref.read(appSettingsProvider.notifier).setWifiOnly(v),

                  ),

              ],

            ),

          ),

          const _SectionHeader('Podcast abonelikleri'),

          ListTile(

            leading: const Icon(Icons.refresh),

            title: const Text('Tüm bölümleri yenile'),

            subtitle: const Text('Abone olduğun programların yeni bölümlerini getir'),

            onTap: () async {

              final count = await ref.read(refreshAllFeedsProvider.future);

              if (context.mounted) {

                ScaffoldMessenger.of(context).showSnackBar(

                  SnackBar(content: Text('$count podcast güncellendi')),

                );

              }

            },

          ),

          ListTile(

            leading: const Icon(Icons.upload_file),

            title: const Text('Podcast listesini dışa aktar'),

            onTap: () => _exportOpml(context, ref),

          ),

          ListTile(

            leading: const Icon(Icons.download),

            title: const Text('Podcast listesini içe aktar'),

            onTap: () => _importOpml(context, ref),

          ),

          if (!PlatformInfo.isWeb) ...[

            ListTile(

              leading: const Icon(Icons.folder_open),

              title: const Text('OPML dosyasından içe aktar'),

              onTap: () => _importOpmlFromFile(context, ref),

            ),

            ListTile(

              leading: const Icon(Icons.save_alt),

              title: const Text('OPML dosyaya kaydet'),

              onTap: () => _exportOpmlToFile(context, ref),

            ),

            ListTile(

              leading: const Icon(Icons.sync),

              title: const Text('OPML klasör senkronu'),

              subtitle: const Text('Klasördeki .opml değişince otomatik içe aktar'),

              onTap: () => _configureOpmlFolder(context, ref),

            ),

          ],

          if (PlatformInfo.isWeb) ...[

            const _SectionHeader('Gelişmiş'),

            settings.when(

              loading: () => const SizedBox.shrink(),

              error: (_, __) => const SizedBox.shrink(),

              data: (s) => ListTile(

                leading: const Icon(Icons.settings_ethernet),

                title: const Text('Ağ proxy'),

                subtitle: Text(

                  s.corsProxyBase?.isNotEmpty == true

                      ? s.corsProxyBase!

                      : 'Varsayılan: localhost:8766 (run.ps1)',

                ),

                trailing: const Icon(Icons.edit),

                onTap: () => _editCorsProxy(context, ref),

              ),

            ),

            const ListTile(

              title: Text('Web sürümü'),

              subtitle: Text('Veriler tarayıcıda kalır. Offline indirme desteklenmez.'),

            ),

          ],

          const _SectionHeader('Hakkında'),

          const ListTile(title: Text('Minimalist Podcast'), subtitle: Text('Sürüm 0.3.0')),

        ],

      ),

    );

  }

}



class _SectionHeader extends StatelessWidget {

  const _SectionHeader(this.title);



  final String title;



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),

      child: Text(

        title.toUpperCase(),

        style: const TextStyle(

          fontSize: 11,

          fontWeight: FontWeight.w600,

          letterSpacing: 0.08,

          color: AppColors.muted,

        ),

      ),

    );

  }

}


