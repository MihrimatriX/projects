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
      orElse: () => AppThemeMode.dark,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    state = AsyncData(mode);
  }
}

ThemeMode resolveThemeMode(AppThemeMode mode, Brightness platform) {
  return switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}

String themeModeLabel(AppThemeMode mode) => switch (mode) {
      AppThemeMode.light => 'Açık',
      AppThemeMode.dark => 'Koyu',
      AppThemeMode.system => 'Sistem',
    };
