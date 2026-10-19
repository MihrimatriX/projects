import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/calendar/presentation/calendar_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

// Router tek sefer oluşturulur: build() içinde olsaydı tema değişince
// yeni router yaratılır ve kullanıcı Ayarlar'dan takvime atılırdı.
final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const CalendarScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeModeProvider);
    final mode = themeAsync.value ?? AppThemeMode.light;
    final platform = WidgetsBinding.instance.platformDispatcher.platformBrightness;

    return MaterialApp.router(
      title: 'Takvim ve Zamanlayıcı',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: resolveThemeMode(mode, platform),
      routerConfig: _router,
    );
  }
}

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  await NotificationService.init();
}
