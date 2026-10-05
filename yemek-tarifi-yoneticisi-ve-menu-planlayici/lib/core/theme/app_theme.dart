import 'package:flutter/material.dart';

/// Design tokens — sıcak mutfak teması (#FAF8F5 / #EA580C)
abstract final class AppColors {
  static const primary = Color(0xFFEA580C);
  static const accent = primary;
  static const accentHover = Color(0xFFC2410C);
  static const accentSoft = Color(0xFFFFEDD5);

  static const bgApp = Color(0xFFFAF8F5);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgMuted = Color(0xFFF3EDE6);
  static const bgHover = Color(0xFFFEF3EB);
  static const border = Color(0xFFE7DDD2);
  static const borderStrong = Color(0xFFD4C4B0);

  static const textPrimary = Color(0xFF1C1917);
  static const textSecondary = Color(0xFF57534E);
  static const textMuted = Color(0xFFA8A29E);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFCA8A04);
  static const danger = Color(0xFFDC2626);

  static const bgDark = Color(0xFF1C1917);
  static const bgCardDark = Color(0xFF292524);
  static const textDark = Color(0xFFFAFAF9);
}

abstract final class AppLayout {
  static const sidebarBreakpoint = 768.0;
  static const mobileNavInset = 72.0;
}

abstract final class AppTheme {
  static const cardRadius = 14.0;
  static const inputRadius = 10.0;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.success,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: dark ? AppColors.bgCardDark : AppColors.bgSurface,
      onSurface: dark ? AppColors.textDark : AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? AppColors.bgDark : AppColors.bgApp,
    );

    final textTheme = base.textTheme.apply(
      bodyColor: dark ? AppColors.textDark : AppColors.textSecondary,
      displayColor: dark ? AppColors.textDark : AppColors.textPrimary,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: dark ? AppColors.bgDark : AppColors.bgApp,
        foregroundColor: dark ? AppColors.textDark : AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: dark ? AppColors.bgCardDark : AppColors.bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: dark ? Colors.white12 : AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.accentSoft,
        labelStyle: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w500, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide.none,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      dividerTheme: DividerThemeData(color: dark ? Colors.white12 : AppColors.border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.bgCardDark : AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: dark ? Colors.white24 : AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: dark ? Colors.white24 : AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputRadius)),
      ),
    );
  }
}
