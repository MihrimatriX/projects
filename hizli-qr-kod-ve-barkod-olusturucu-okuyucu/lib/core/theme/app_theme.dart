import 'package:flutter/material.dart';

/// Spacing & radii — design/index.html :root
abstract final class AppSpacing {
  static const panel = 24.0;
  static const compact = 16.0;
  static const section = 20.0;
  static const field = 12.0;
  static const panelRadius = 16.0;
  static const inputRadius = 8.0;
  static const navBarHeight = 80.0;
}

/// Design tokens — synced from design/index.html :root variables.
abstract final class AppColors {
  static const primary = Color(0xFF6366F1);
  static const accent = primary;
  static const accentHover = Color(0xFF4F46E5);

  static const bgApp = Color(0xFF0C0C0E);
  static const bgPanel = Color(0xFF161618);
  static const bgInput = Color(0xFF1E1E22);
  static const bgHover = Color(0xFF2A2A30);
  static const bgRaised = Color(0xFF1A1A1E);

  static const foreground = Color(0xFFF4F4F5);
  static const textSecondary = Color(0xFFA1A1AA);
  static const muted = Color(0xFF71717A);
  static const border = Color(0xFF333338);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  static const qrFg = Color(0xFF000000);
  static const qrBg = Color(0xFFFFFFFF);

  // Light theme variants
  static const bgAppLight = Color(0xFFF4F4F5);
  static const bgPanelLight = Color(0xFFFFFFFF);
  static const foregroundLight = Color(0xFF18181B);
  static const mutedLight = Color(0xFF71717A);
  static const borderLight = Color(0xFFE4E4E7);

  static const accentSoft = Color(0x1F6366F1);
}

abstract final class AppTheme {
  static InputDecorationTheme _inputTheme(bool dark) => InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.bgInput : AppColors.bgPanelLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: dark ? AppColors.border : AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: BorderSide(color: dark ? AppColors.border : AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: TextStyle(
          color: dark ? AppColors.foreground : AppColors.foregroundLight,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      );

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.success,
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: AppColors.bgPanelLight,
      onSurface: AppColors.foregroundLight,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgAppLight,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.bgAppLight,
        foregroundColor: AppColors.foregroundLight,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgPanelLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),
      inputDecorationTheme: _inputTheme(false),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSpacing.navBarHeight,
        backgroundColor: AppColors.bgPanelLight.withValues(alpha: 0.92),
        indicatorColor: AppColors.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.muted,
            size: 24,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
        ),
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
      surface: AppColors.bgPanel,
      onSurface: AppColors.foreground,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgApp,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.bgApp,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: _inputTheme(true),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSpacing.navBarHeight,
        backgroundColor: AppColors.bgPanel.withValues(alpha: 0.92),
        indicatorColor: AppColors.accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.muted,
            size: 24,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          ),
        ),
      ),
    );
  }
}
