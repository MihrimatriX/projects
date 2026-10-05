import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/settings_provider.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final tokens = AppThemeTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Tema'),
            subtitle: Text(_themeLabel(mode)),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.settings_brightness, size: 18),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).setMode(s.first),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Dil'),
            subtitle: Text('Türkçe', style: TextStyle(color: tokens.textMuted)),
          ),
          ListTile(
            title: const Text('Gizlilik'),
            subtitle: Text(
              'Tüm dönüşümler cihazınızda yapılır; metin sunucuya gönderilmez.',
              style: TextStyle(color: tokens.textMuted),
            ),
          ),
          ListTile(
            title: const Text('Sürüm'),
            subtitle: Text('1.0.0', style: TextStyle(color: tokens.textMuted)),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Aydınlık',
        ThemeMode.dark => 'Koyu',
        ThemeMode.system => 'Sistem',
      };
}
