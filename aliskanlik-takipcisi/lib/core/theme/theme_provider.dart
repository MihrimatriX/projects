import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, amoled, system }

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<AppThemeMode> {
  static const _key = 'theme_mode';

  @override
  Future<AppThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = AsyncData(mode);
  }
}

({ThemeMode mode, ThemeData? darkTheme}) resolveAppTheme(
  AppThemeMode mode,
  Brightness platform,
) {
  return switch (mode) {
    AppThemeMode.light => (mode: ThemeMode.light, darkTheme: null),
    AppThemeMode.dark => (mode: ThemeMode.dark, darkTheme: null),
    AppThemeMode.amoled => (mode: ThemeMode.dark, darkTheme: null),
    AppThemeMode.system => (
        mode: platform == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        darkTheme: null,
      ),
  };
}

String themeModeLabel(AppThemeMode mode) => switch (mode) {
      AppThemeMode.light => 'Açık',
      AppThemeMode.dark => 'Koyu',
      AppThemeMode.amoled => 'AMOLED (siyah)',
      AppThemeMode.system => 'Sistem',
    };

bool useAmoledTheme(AppThemeMode mode) => mode == AppThemeMode.amoled;
