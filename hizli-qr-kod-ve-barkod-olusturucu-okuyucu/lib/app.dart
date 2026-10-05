import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/help/presentation/help_screen.dart';
import 'features/qr/presentation/create_screen.dart';
import 'features/qr/presentation/qr_screen.dart';
import 'features/scan/presentation/scan_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/shell/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Router bir kez kurulur ve saklanır: build her çalıştığında (ör. tema değişince)
// yeniden yaratılırsa gezinme durumu sıfırlanır ve kullanıcı başa atılır.
GoRouter? _router;

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeModeProvider);
    final mode = themeAsync.value ?? AppThemeMode.dark;
    final platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;

    final router = _router ??= GoRouter(
      navigatorKey: _rootNavigatorKey,
      routes: [
        GoRoute(
          path: '/qr',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, state) => QrScreen(initialText: state.extra as String?),
        ),
        GoRoute(
          path: '/settings',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/help',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, __) => const HelpScreen(),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (_, state) {
                    final extra = state.extra;
                    final tab = state.uri.queryParameters['tab'];
                    return CreateScreen(
                      initialText: extra is String ? extra : null,
                      initialTab: int.tryParse(tab ?? '') ?? 0,
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/scan',
                  builder: (_, __) => const ScanScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'QR Kod & Barkod',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: resolveThemeMode(mode, platform),
      routerConfig: router,
    );
  }
}
