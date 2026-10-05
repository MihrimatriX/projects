import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, AppThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends AsyncNotifier<AppThemeMode> {
  static const _key = 'theme_mode_v1';

  @override
  Future<AppThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => AppThemeMode.light,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = AsyncData(mode);
  }
}

({ThemeMode mode}) resolveAppTheme(AppThemeMode mode, Brightness platform) {
  return switch (mode) {
    AppThemeMode.light => (mode: ThemeMode.light),
    AppThemeMode.dark => (mode: ThemeMode.dark),
    AppThemeMode.system => (
        mode: platform == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      ),
  };
}

String themeModeLabel(AppThemeMode mode) => switch (mode) {
      AppThemeMode.light => 'Açık (mutfak)',
      AppThemeMode.dark => 'Koyu',
      AppThemeMode.system => 'Sistem',
    };
