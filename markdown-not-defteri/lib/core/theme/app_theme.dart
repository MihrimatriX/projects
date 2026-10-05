import 'package:flutter/material.dart';

/// Design tokens — synced from design/css/tokens.css
abstract final class AppColors {
  static const primary = Color(0xFF0969DA);
  static const accent = primary;
  static const accentHover = Color(0xFF0550AE);

  static const bg = Color(0xFFFAF9F7);
  static const bgEditor = Color(0xFFFAF9F7);
  static const bgPreview = Color(0xFFFFFFFF);
  static const bgToolbar = Color(0xFFF5F4F2);
  static const surface = Color(0xFFFFFFFF);

  static const foreground = Color(0xFF2C2C2C);
  static const textSecondary = Color(0xFF454545);
  static const textPreview = Color(0xFF3D3D3D);
  static const muted = Color(0xFF9A9A9A);
  static const border = Color(0xFFE8E6E3);

  static const bgHover = Color(0xFFEEECEA);
  static const codeBg = Color(0xFFF6F4F1);
  static const codeBlockBg = Color(0xFF2D2D2D);
  static const codeBlockFg = Color(0xFFE6E6E6);
  static const unsaved = Color(0xFFBF8700);

  static const success = Color(0xFF1A7F37);
  static const warning = Color(0xFFEAB308);
  static const danger = Color(0xFFCF222E);

  // Dark theme (tokens.css [data-theme="dark"])
  static const bgDark = Color(0xFF1A1A1A);
  static const bgEditorDark = Color(0xFF1A1A1A);
  static const bgPreviewDark = Color(0xFF222222);
  static const bgToolbarDark = Color(0xFF252525);
  static const surfaceDark = Color(0xFF252525);
  static const foregroundDark = Color(0xFFE6E6E6);
  static const textSecondaryDark = Color(0xFFB0B0B0);
  static const mutedDark = Color(0xFF888888);
  static const borderDark = Color(0xFF333333);
  static const bgHoverDark = Color(0xFF2E2E2E);
  static const codeBgDark = Color(0xFF2A2A2A);
  static const textPreviewDark = Color(0xFFC8C8C8);
  static const accentSoft = Color(0x1A0969DA);
}

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.success,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.foreground,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.bgToolbar,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerColor: AppColors.border,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.success,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.foregroundDark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgDark,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.bgToolbarDark,
        foregroundColor: AppColors.foregroundDark,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.borderDark),
        ),
      ),
      dividerColor: AppColors.borderDark,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
