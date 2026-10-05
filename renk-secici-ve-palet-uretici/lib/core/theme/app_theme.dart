import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/palette_core.dart';

/// Design tokens — synced from design/desktop.html :root variables.
abstract final class AppColors {
  static const primary = Color(0xFFA855F7);
  static const accent = primary;
  static const accentSoft = Color(0x26A855F7);

  static const bg = Color(0xFF0A0A0B);
  static const bgPanel = Color(0xFF141416);
  static const bgElevated = Color(0xFF1C1C1F);
  static const bgHover = Color(0xFF27272A);
  static const surface = bgPanel;

  static const foreground = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFFA1A1AA);
  static const muted = Color(0xFF71717A);
  static const border = Color(0xFF2A2A2E);

  static const passAa = Color(0xFF22C55E);
  static const passAaa = Color(0xFF16A34A);
  static const failContrast = Color(0xFFEF4444);
  static const success = passAa;
  static const warning = Color(0xFFEAB308);
  static const danger = failContrast;
}

abstract final class AppRadius {
  static const sm = 6.0;
  static const md = 10.0;
  static const lg = 14.0;
  static const xl = 20.0;
}

abstract final class AppTypography {
  static const mono = 'Consolas';
  static const ui = 'Segoe UI';
}

abstract final class AppTheme {
  static ThemeData fromExtracted(ExtractedTheme t) {
    final brightness = t.isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.bgApp,
      fontFamily: AppTypography.ui,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.accent,
        onPrimary: Colors.white,
        secondary: AppColors.passAa,
        onSecondary: Colors.white,
        error: AppColors.failContrast,
        onError: Colors.white,
        surface: t.bgPanel,
        onSurface: t.textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.bgPanel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: t.border),
        ),
      ),
      dividerColor: t.border,
      splashColor: t.accent.withValues(alpha: 0.12),
      highlightColor: t.accent.withValues(alpha: 0.08),
    );
  }

  static void applySystemChrome(ExtractedTheme t) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: t.bgPanel,
      systemNavigationBarIconBrightness: t.isDark ? Brightness.light : Brightness.dark,
    ));
  }

  static ThemeData get dark => fromExtracted(const ExtractedTheme(
        bgApp: AppColors.bg,
        bgPanel: AppColors.bgPanel,
        bgElevated: AppColors.bgElevated,
        bgHover: AppColors.bgHover,
        border: AppColors.border,
        borderFocus: AppColors.accent,
        textPrimary: AppColors.foreground,
        textSecondary: AppColors.textSecondary,
        textMuted: AppColors.muted,
        accent: AppColors.accent,
        isDark: true,
      ));
}
