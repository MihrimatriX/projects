import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/chain/presentation/chain_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/stats/presentation/stats_screen.dart';

final appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
        GoRoute(path: '/chain', builder: (_, __) => const ChainScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeModeProvider);
    final mode = themeAsync.value ?? AppThemeMode.system;
    final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final resolved = resolveAppTheme(mode, platform);
    final darkTheme = useAmoledTheme(mode) ? AppTheme.amoled : AppTheme.dark;

    return MaterialApp.router(
      title: 'Alışkanlık Takipçisi',
      theme: AppTheme.light,
      darkTheme: darkTheme,
      themeMode: resolved.mode,
      routerConfig: appRouter,
    );
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
}
