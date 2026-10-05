import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'features/pomodoro/presentation/pomodoro_screen.dart';
import 'features/reports/presentation/reports_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/timer/presentation/timer_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/timer',
      routes: [
        GoRoute(path: '/', redirect: (_, __) => '/timer'),
        ShellRoute(
          builder: (_, __, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/timer', builder: (_, __) => const TimerScreen()),
            GoRoute(path: '/pomodoro', builder: (_, __) => const PomodoroScreen()),
            GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Odaklanma',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
