import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/tools/presentation/text_tools_screen.dart';

// Router build() dışında tek sefer oluşturulur; aksi halde tema her
// değiştiğinde yeni router kurulur ve uygulama '/' sayfasına geri atılırdı.
final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const TextToolsScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tema seçimi Riverpod StateNotifier'da tutulur, SharedPreferences'a yazılır.
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Metin Dönüştürücü',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
