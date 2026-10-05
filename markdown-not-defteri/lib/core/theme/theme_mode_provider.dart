import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference { sepia, dark, system }

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceNotifier, AppThemePreference>(
  ThemePreferenceNotifier.new,
);

class ThemePreferenceNotifier extends Notifier<AppThemePreference> {
  static const _key = 'theme_pref_v1';

  @override
  AppThemePreference build() {
    _load();
    return AppThemePreference.sepia;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final next = AppThemePreference.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppThemePreference.sepia,
    );
    if (next != state) state = next;
  }

  Future<void> set(AppThemePreference pref) async {
    state = pref;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, pref.name);
  }
}

ThemeMode themeModeFromPreference(AppThemePreference pref) {
  return switch (pref) {
    AppThemePreference.sepia => ThemeMode.light,
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.system => ThemeMode.system,
  };
}
