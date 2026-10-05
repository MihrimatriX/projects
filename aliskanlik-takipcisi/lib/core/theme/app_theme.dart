import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFF6366F1);
  static const primaryHover = Color(0xFF4F46E5);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFF0FDF4);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const bgLight = Color(0xFFFAF9F7);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textLight = Color(0xFF1F2937);
  static const textMutedLight = Color(0xFF6B7280);
  static const borderLight = Color(0xFFF0F0F0);

  static const bgDark = Color(0xFF1A1A2E);
  static const surfaceDark = Color(0xFF252542);
  static const textDark = Color(0xFFF3F4F6);
  static const textMutedDark = Color(0xFF9CA3AF);

  static const bgAmoled = Color(0xFF000000);
  static const surfaceAmoled = Color(0xFF0D0D0D);

  static const heatmap0 = Color(0xFFEBEDF0);
  static const heatmap1 = Color(0xFF9BE9A8);
  static const heatmap2 = Color(0xFF40C463);
  static const heatmap3 = Color(0xFF30A14E);
  static const heatmap4 = Color(0xFF216E39);

  static const habitPalette = [
    0xFF6366F1,
    0xFF10B981,
    0xFFF59E0B,
    0xFFEF4444,
    0xFF8B5CF6,
    0xFF06B6D4,
    0xFFEC4899,
    0xFF14B8A6,
  ];

  static const habitIcons = [
    '🌱', '💧', '🏃', '📖', '🧘', '💪', '🥗', '😴', '✍️', '🎯',
  ];

  static const radiusCard = 16.0;
  static const radiusInput = 8.0;
  static const radiusCheck = 12.0;
  static const sectionGap = 24.0;
  static const contentPadding = 20.0;
}

abstract final class AppTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        bg: AppColors.bgLight,
        surface: AppColors.surfaceLight,
        fg: AppColors.textLight,
        muted: AppColors.textMutedLight,
        border: AppColors.borderLight,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        bg: AppColors.bgDark,
        surface: AppColors.surfaceDark,
        fg: AppColors.textDark,
        muted: AppColors.textMutedDark,
        border: Colors.white.withValues(alpha: 0.08),
      );

  static ThemeData get amoled => _build(
        brightness: Brightness.dark,
        bg: AppColors.bgAmoled,
        surface: AppColors.surfaceAmoled,
        fg: AppColors.textDark,
        muted: AppColors.textMutedDark,
        border: Colors.white.withValues(alpha: 0.08),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color fg,
    required Color muted,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: fg, displayColor: fg);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.success,
        onSecondary: Colors.white,
        error: AppColors.danger,
        onError: Colors.white,
        surface: surface,
        onSurface: fg,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.02,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          side: BorderSide(color: border),
        ),
      ),
      dividerColor: border,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surface : fg,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? fg : bg,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusInput),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  static Color muted(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
  }

  static Color border(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight;
  }

  static Color successBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.successBg;
  }

  static bool isAmoled(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor == AppColors.bgAmoled;
}
