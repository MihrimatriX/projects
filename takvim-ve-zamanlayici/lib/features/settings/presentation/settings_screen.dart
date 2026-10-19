import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/file_import.dart';
import '../../../core/ics_export.dart';
import '../../../core/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/settings_section.dart';
import '../../events/providers/events_provider.dart';
import '../../timer/providers/pomodoro_provider.dart';
import '../providers/sync_settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  bool _pomodoroNotify = true;
  bool _loading = true;
  bool _caldavInitialized = false;
  late final TextEditingController _caldavUrlCtrl;

  @override
  void initState() {
    super.initState();
    _caldavUrlCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _caldavUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final n = await NotificationService.isEnabled();
    final p = await NotificationService.isPomodoroEnabled();
    if (!mounted) return;
    setState(() {
      _notifications = n;
      _pomodoroNotify = p;
      _loading = false;
    });
  }

  Future<void> _importIcs() async {
    final raw = await pickIcsFileContent();
    if (raw == null) return;
    try {
      final count = await ref.read(eventsProvider.notifier).importFromIcs(raw);
      _snack('$count etkinlik içe aktarıldı');
    } catch (e) {
      _snack('ICS hatası: $e');
    }
  }

  Future<void> _importJson() async {
    final raw = await pickTextFileContent(extensions: ['json']);
    if (raw == null) return;
    try {
      final count = await ref.read(eventsProvider.notifier).importFromJson(raw);
      _snack('$count etkinlik içe aktarıldı');
    } catch (e) {
      _snack('JSON hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeAsync = ref.watch(themeModeProvider);
    final pomo = ref.watch(pomodoroProvider);
    final syncAsync = ref.watch(syncSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sync = syncAsync.value;
    if (sync != null && !_caldavInitialized) {
      _caldavUrlCtrl.text = sync.caldavUrl;
      _caldavInitialized = true;
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back, size: 20),
                label: const Text('Takvim'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ayarlar',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.02,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  themeAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (mode) => SettingsSection(
                      title: 'Görünüm',
                      children: [
                        SettingsRow(
                          label: 'Tema',
                          description: 'Açık, koyu veya sistem',
                          trailing: ThemeSegmentedControl(
                            mode: mode,
                            onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m),
                          ),
                        ),
                        SettingsRow(
                          label: 'Saat dilimi',
                          description: 'Europe/Istanbul',
                          trailing: Text(
                            'TRT (UTC+3)',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SettingsSection(
                    title: 'Veri',
                    children: [
                      SettingsRow(
                        label: 'ICS dışa aktar',
                        description: 'Standart iCal formatı',
                        trailing: OutlinedButton(
                          onPressed: () async {
                            final events = ref.read(eventsProvider).value ?? [];
                            if (events.isEmpty) {
                              _snack('Dışa aktarılacak etkinlik yok');
                              return;
                            }
                            await SharePlus.instance.share(ShareParams(
                                text: exportEventsToIcs(events), subject: 'Takvim.ics'));
                          },
                          child: const Text('Dışa aktar'),
                        ),
                      ),
                      if (!kIsWeb)
                        SettingsRow(
                          label: 'ICS içe aktar',
                          description: 'Maks. 512 KB',
                          trailing: OutlinedButton(
                            onPressed: _importIcs,
                            child: const Text('Dosya seç'),
                          ),
                        ),
                      SettingsRow(
                        label: 'JSON yedek',
                        description: 'Tam yerel yedekleme',
                        trailing: OutlinedButton(
                          onPressed: () async {
                            final json = ref.read(eventsProvider.notifier).exportToJson();
                            await SharePlus.instance
                                .share(ShareParams(text: json, subject: 'takvim-yedek.json'));
                          },
                          child: const Text('Yedekle'),
                        ),
                      ),
                      if (!kIsWeb)
                        SettingsRow(
                          label: 'JSON yedek içe aktar',
                          trailing: OutlinedButton(
                            onPressed: _importJson,
                            child: const Text('Dosya seç'),
                          ),
                        ),
                      SettingsRow(
                        label: 'KVKK — tüm veriyi sil',
                        description: 'Geri alınamaz',
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Emin misiniz?'),
                                content: const Text('Tüm etkinlikler kalıcı olarak silinecek.'),
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
                            if (ok == true) {
                              await ref.read(eventsProvider.notifier).clearAll();
                              _snack('Etkinlikler silindi');
                            }
                          },
                          child: const Text('Sil'),
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Bildirimler',
                    children: [
                      SettingsRow(
                        label: 'Etkinlik hatırlatıcıları',
                        description: NotificationService.supported
                            ? '5–60 dk önce'
                            : 'Bu platformda sistem bildirimi yok; uygulama açıkken uygulama içi uyarı',
                        trailing: Switch(
                          value: _notifications,
                          onChanged: (v) async {
                            setState(() => _notifications = v);
                            await NotificationService.setEnabled(v);
                            if (v) {
                              final events = ref.read(eventsProvider).value ?? [];
                              await NotificationService.rescheduleEventReminders(events);
                            }
                          },
                        ),
                      ),
                      if (NotificationService.supported)
                        SettingsRow(
                          label: 'Pomodoro tamamlandığında',
                          trailing: Switch(
                            value: _pomodoroNotify,
                            onChanged: (v) async {
                              setState(() => _pomodoroNotify = v);
                              await NotificationService.setPomodoroEnabled(v);
                            },
                          ),
                        ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Pomodoro',
                    children: [
                      SettingsRow(
                        label: 'Otomatik zaman bloklama',
                        description: 'Odak oturumu bitince takvime kaydet',
                        trailing: Switch(
                          value: pomo.settings.autoTimeBlock,
                          onChanged: (v) => ref.read(pomodoroProvider.notifier).updateSettings(
                                pomo.settings.copyWith(autoTimeBlock: v),
                              ),
                        ),
                      ),
                      SettingsRow(
                        label: 'Odak süresi',
                        description: '${pomo.settings.focusMinutes} dakika',
                        trailing: _DurationStepper(
                          value: pomo.settings.focusMinutes,
                          onChanged: (v) => ref.read(pomodoroProvider.notifier).updateSettings(
                                pomo.settings.copyWith(focusMinutes: v),
                              ),
                        ),
                      ),
                      SettingsRow(
                        label: 'Kısa mola',
                        description: '${pomo.settings.shortBreakMinutes} dakika',
                        trailing: _DurationStepper(
                          value: pomo.settings.shortBreakMinutes,
                          onChanged: (v) => ref.read(pomodoroProvider.notifier).updateSettings(
                                pomo.settings.copyWith(shortBreakMinutes: v),
                              ),
                        ),
                      ),
                    ],
                  ),
                  SettingsSection(
                    title: 'Senkronizasyon',
                    banner: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      color: isDark ? AppColors.bgSidebarDark : AppColors.bgSidebarLight,
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 18,
                              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'CalDAV iki yönlü sync — Faz 2, yakında',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('CalDAV sunucu URL',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _caldavUrlCtrl,
                              decoration: const InputDecoration(
                                hintText: 'https://caldav.example.com/...',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: sync == null
                                    ? null
                                    : () async {
                                        await ref.read(syncSettingsProvider.notifier).save(
                                              sync.copyWith(caldavUrl: _caldavUrlCtrl.text.trim()),
                                            );
                                        _snack('CalDAV URL kaydedildi');
                                      },
                                child: const Text('Kaydet'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Sürüm 1.1.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _DurationStepper extends StatelessWidget {
  const _DurationStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove, size: 18),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Text('$value'),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add, size: 18),
          onPressed: value < 120 ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

Future<String?> pickIcsFileContent() => pickTextFileContent(extensions: ['ics']);
