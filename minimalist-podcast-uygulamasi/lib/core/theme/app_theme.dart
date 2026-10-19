import 'package:flutter/material.dart';

/// Design tokens — synced from design/web.html :root variables.
abstract final class AppColors {
  static const primary = Color(0xFF1DB954);
  static const accent = primary;
  static const accentHover = Color(0xFF1ED760);

  static const bg = Color(0xFF121212);
  static const bgElevated = Color(0xFF1E1E1E);
  static const bgPlayer = Color(0xFF181818);
  static const bgHover = Color(0xFF2A2A2A);
  static const bgPlaying = Color(0xFF282828);
  static const bgInput = Color(0xFF2A2A2A);
  static const surface = bgElevated;

  static const foreground = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB3B3B3);
  static const muted = Color(0xFF727272);
  static const border = Color(0xFF333333);

  static const progressBg = Color(0xFF535353);
  static const progressFill = primary;
  static const danger = Color(0xFFE91429);
}

abstract final class AppLayout {
  static const sidebarWidth = 240.0;
  static const playerHeight = 90.0;
  static const miniPlayerHeight = 72.0;
  static const navHeight = 80.0;
  static const artRadius = 4.0;
  static const cardRadius = 8.0;
  static const wideBreakpoint = 1024.0;
}

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.black,
      secondary: AppColors.primary,
      onSecondary: Colors.black,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.bgElevated,
      onSurface: AppColors.textSecondary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Segoe UI',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.foreground,
          letterSpacing: -0.01,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgElevated,
        indicatorColor: AppColors.bgPlaying,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.primary : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.selected);
          return IconThemeData(color: active ? AppColors.primary : AppColors.muted);
        }),
      ),
      dividerColor: AppColors.border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.cardRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppLayout.cardRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.progressFill,
        inactiveTrackColor: AppColors.progressBg,
        thumbColor: AppColors.progressFill,
        trackHeight: 4,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
      ),
    );
  }
}
