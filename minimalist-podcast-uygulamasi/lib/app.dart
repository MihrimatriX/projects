import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'core/player/player_shortcuts.dart';
import 'core/theme/app_theme.dart';
import 'features/downloads/presentation/downloads_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/player/presentation/player_screen.dart';
import 'features/queue/presentation/queue_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/queue', builder: (_, __) => const QueueScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/downloads', builder: (_, __) => const DownloadsScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
              ],
            ),
          ],
        ),
        GoRoute(path: '/player', builder: (_, __) => const PlayerScreen()),
      ],
    );

    return PlayerShortcuts(
      child: MaterialApp.router(
        title: 'Minimalist Podcast',
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
