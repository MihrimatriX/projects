import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/home_widget_service.dart';
import '../../../core/notification_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/weekly_report.dart';
import '../../../core/widgets/app_header.dart';
import '../../../core/widgets/settings_group.dart';
import '../../habits/data/habits_repository.dart';
import '../../habits/providers/habits_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _reminderEnabled = false;
  bool _weeklyEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _weeklyTime = const TimeOfDay(hour: 10, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await NotificationService.isEnabled();
    final weekly = await NotificationService.isWeeklyEnabled();
    final (hour, minute) = await NotificationService.getTime();
    final (wHour, wMinute) = await NotificationService.getWeeklyTime();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = enabled;
      _weeklyEnabled = weekly;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _weeklyTime = TimeOfDay(hour: wHour, minute: wMinute);
      _loading = false;
    });
  }

  Future<void> _pickTime({required bool weekly}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: weekly ? _weeklyTime : _reminderTime,
    );
    if (picked == null) return;
    setState(() {
      if (weekly) {
        _weeklyTime = picked;
      } else {
        _reminderTime = picked;
      }
    });
    if (weekly) {
      await NotificationService.setWeeklyTime(picked.hour, picked.minute);
    } else {
      await NotificationService.setTime(picked.hour, picked.minute);
    }
  }

  Future<void> _shareWeeklyReport() async {
    final habits = ref.read(habitsProvider).value ?? [];
    try {
      await SharePlus.instance.share(
        ShareParams(text: WeeklyReport.generate(habits), subject: 'Haftalık Alışkanlık Raporu'),
      );
    } catch (_) {
      // Paylaşım sayfası olmayan platformlarda panoya düş.
      await _copyWeeklyReport();
    }
  }

  Future<void> _copyWeeklyReport() async {
    final habits = ref.read(habitsProvider).value ?? [];
    await Clipboard.setData(ClipboardData(text: WeeklyReport.generate(habits)));
    if (mounted) _showSnack('Haftalık rapor panoya kopyalandı');
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      _showSnack('Panoda içe aktarılacak JSON yok. Önce yedeği kopyalayın.');
      return;
    }
    final List<dynamic> preview;
    try {
      preview = HabitsRepository.decodeHabits(text);
    } on FormatException catch (e) {
      _showSnack('İçe aktarılamadı: ${e.message}');
      return;
    }
    final current = ref.read(habitsProvider).value?.length ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedekten geri yükle'),
        content: Text(
          'Panodaki ${preview.length} alışkanlık mevcut $current alışkanlığın yerine geçecek. '
          'Devam etmeden önce mevcut veriyi JSON olarak dışa aktarabilirsiniz.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri yükle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final n = await ref.read(habitsProvider.notifier).importJson(text);
      if (mounted) _showSnack('$n alışkanlık içe aktarıldı');
    } on FormatException catch (e) {
      if (mounted) _showSnack('İçe aktarılamadı: ${e.message}');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final themeAsync = ref.watch(themeModeProvider);

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                const AppHeader(
                  title: 'Ayarlar',
                  subtitle: 'Tema, hatırlatıcı, dışa aktarma',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppColors.contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      themeAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (mode) => SettingsGroup(
                          title: 'Görünüm',
                          children: [
                            const SettingsRow(
                              label: 'Tema',
                              description: 'Açık, koyu, sistem veya AMOLED',
                              borderTop: false,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: ThemeSegment(
                                value: mode,
                                onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SettingsGroup(
                        title: 'Hatırlatıcılar',
                        children: [
                          if (NotificationService.supported) ...[
                            SettingsRow(
                              label: 'Günlük hatırlatıcı',
                              description: _reminderEnabled
                                  ? '${_reminderTime.format(context)} · Sistem bildirimi'
                                  : 'Kapalı',
                              trailing: DesignToggle(
                                value: _reminderEnabled,
                                onChanged: (v) async {
                                  setState(() => _reminderEnabled = v);
                                  await NotificationService.setEnabled(v);
                                },
                              ),
                              onTap: _reminderEnabled ? () => _pickTime(weekly: false) : null,
                              borderTop: false,
                            ),
                            SettingsRow(
                              label: 'Haftalık rapor',
                              description: _weeklyEnabled
                                  ? 'Pazar ${_weeklyTime.format(context)} · Paylaşım özeti'
                                  : 'Kapalı',
                              trailing: DesignToggle(
                                value: _weeklyEnabled,
                                onChanged: (v) async {
                                  setState(() => _weeklyEnabled = v);
                                  await NotificationService.setWeeklyEnabled(v);
                                },
                              ),
                              onTap: _weeklyEnabled ? () => _pickTime(weekly: true) : null,
                            ),
                          ] else
                            const SettingsRow(
                              label: 'Bildirimler',
                              description: 'Bu platformda zamanlanmış bildirim desteklenmiyor',
                              borderTop: false,
                            ),
                          SettingsRow(
                            label: 'Raporu şimdi paylaş',
                            description: 'E-posta veya mesaj uygulaması ile gönder',
                            onTap: _shareWeeklyReport,
                          ),
                          SettingsRow(
                            label: 'Raporu panoya kopyala',
                            description: 'Bu haftanın özetini metin olarak kopyala',
                            onTap: _copyWeeklyReport,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SettingsGroup(
                        title: 'Veri',
                        children: [
                          const SettingsRow(
                            label: 'Tamamen offline',
                            description: 'SharedPreferences · Bulut yok',
                            borderTop: false,
                          ),
                          if (HomeWidgetService.supported)
                            const SettingsRow(
                              label: 'Ana ekran widget\'ı',
                              description: 'Android ana ekrana widget ekleyin',
                            ),
                          const SettingsRow(
                            label: 'Sürüm',
                            description: '0.3.0',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ExportButton(
                        label: 'JSON dışa aktar',
                        onPressed: () async {
                          final json = await ref.read(habitsProvider.notifier).exportJson();
                          await Clipboard.setData(ClipboardData(text: json));
                          _showSnack('habits.json panoya kopyalandı');
                        },
                      ),
                      const SizedBox(height: 8),
                      _ExportButton(
                        label: 'CSV dışa aktar',
                        onPressed: () async {
                          final csv = ref.read(habitsProvider.notifier).exportCsv();
                          await Clipboard.setData(ClipboardData(text: csv));
                          _showSnack('habits.csv panoya kopyalandı');
                        },
                      ),
                      const SizedBox(height: 8),
                      _ExportButton(
                        label: 'JSON içe aktar (panodan)',
                        icon: Icons.download_outlined,
                        onPressed: _importFromClipboard,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.upload_outlined,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(AppColors.radiusInput),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppColors.radiusInput),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusInput),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
