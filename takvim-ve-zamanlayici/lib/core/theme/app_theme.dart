import 'package:flutter/material.dart';

/// Design tokens — design/index.html ve hafta-grid.html :root değişkenleri.
abstract final class AppColors {
  static const accent = Color(0xFF2563EB);
  static const accentDark = Color(0xFF3B82F6);
  static const primary = accent;
  static const nowLine = Color(0xFFEF4444);
  static const timerBreak = Color(0xFF10B981);

  static const bgAppLight = Color(0xFFFAFAFA);
  static const bgGridLight = Color(0xFFFFFFFF);
  static const bgSidebarLight = Color(0xFFF9FAFB);
  static const bgHoverLight = Color(0xFFF3F4F6);
  static const borderLight = Color(0xFFE5E7EB);
  static const borderStrongLight = Color(0xFFD1D5DB);
  static const textPrimaryLight = Color(0xFF111827);
  static const textSecondaryLight = Color(0xFF374151);
  static const textMutedLight = Color(0xFF6B7280);

  static const bgAppDark = Color(0xFF111827);
  static const bgGridDark = Color(0xFF1F2937);
  static const bgSidebarDark = Color(0xFF18202C);
  static const bgHoverDark = Color(0xFF374151);
  static const borderDark = Color(0xFF374151);
  static const borderStrongDark = Color(0xFF4B5563);
  static const textPrimaryDark = Color(0xFFF9FAFB);
  static const textSecondaryDark = Color(0xFFE5E7EB);
  static const textMutedDark = Color(0xFF9CA3AF);

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);

  /// design/hafta-grid.html event-1 … event-4 paleti
  static const eventPalette = [
  Color(0xFF2563EB),
  Color(0xFF16A34A),
  Color(0xFFD97706),
  Color(0xFFDB2777),
  ];

  static const eventBackgroundsLight = [
    Color(0xFFDBEAFE),
    Color(0xFFDCFCE7),
    Color(0xFFFEF3C7),
    Color(0xFFFCE7F3),
  ];

  static Color accentOf(bool dark) => dark ? accentDark : accent;

  static Color bgHover(bool dark) => dark ? bgHoverDark : bgHoverLight;

  static Color eventBackground(int index, {required bool dark}) {
    final i = index % eventPalette.length;
    if (dark) return eventPalette[i].withValues(alpha: 0.22);
    return eventBackgroundsLight[i];
  }

  static Color eventBorder(int index) => eventPalette[index % eventPalette.length];
}

abstract final class AppLayout {
  static const sidebarWidth = 200.0;
  static const pomodoroWidth = 280.0;
  static const wideBreakpoint = 1024.0;
  static const slotHeight = 48.0;
  static const hourLabelWidth = 56.0;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final accent = AppColors.accentOf(dark);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: AppColors.nowLine,
      onError: Colors.white,
      surface: dark ? AppColors.bgGridDark : AppColors.bgGridLight,
      onSurface: dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? AppColors.bgAppDark : AppColors.bgAppLight,
      dividerColor: dark ? AppColors.borderDark : AppColors.borderLight,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          side: BorderSide(color: dark ? AppColors.borderDark : AppColors.borderLight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.bgGridDark : AppColors.bgGridLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: dark ? AppColors.borderDark : AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? AppColors.bgGridDark : AppColors.bgGridLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
