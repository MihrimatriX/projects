import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData light = _build(Brightness.light);
  static ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final panel = isDark ? AppColors.darkPanel : AppColors.lightPanel;
    final sidebar = isDark ? AppColors.darkSidebar : AppColors.lightSidebar;
    final border = isDark ? AppColors.border : AppColors.borderLight;
    final onSurface =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.accent,
        onPrimary: AppColors.darkBg,
        secondary: AppColors.accentHover,
        onSecondary: AppColors.darkBg,
        surface: panel,
        onSurface: onSurface,
        error: AppColors.error,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkInput : AppColors.lightInput,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.borderFocus, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? AppColors.darkPanel : AppColors.lightPanel,
        contentTextStyle: GoogleFonts.inter(color: onSurface, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      extensions: [
        AppThemeTokens(
          panel: panel,
          sidebar: sidebar,
          hover: isDark ? AppColors.darkHover : AppColors.lightHover,
          selected: isDark ? AppColors.darkSelected : AppColors.lightSelected,
          input: isDark ? AppColors.darkInput : AppColors.lightInput,
          border: border,
          textSecondary:
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          textMuted:
              isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        ),
      ],
    );
  }
}

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.panel,
    required this.sidebar,
    required this.hover,
    required this.selected,
    required this.input,
    required this.border,
    required this.textSecondary,
    required this.textMuted,
  });

  final Color panel;
  final Color sidebar;
  final Color hover;
  final Color selected;
  final Color input;
  final Color border;
  final Color textSecondary;
  final Color textMuted;

  static AppThemeTokens of(BuildContext context) =>
      Theme.of(context).extension<AppThemeTokens>()!;

  @override
  AppThemeTokens copyWith({
    Color? panel,
    Color? sidebar,
    Color? hover,
    Color? selected,
    Color? input,
    Color? border,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return AppThemeTokens(
      panel: panel ?? this.panel,
      sidebar: sidebar ?? this.sidebar,
      hover: hover ?? this.hover,
      selected: selected ?? this.selected,
      input: input ?? this.input,
      border: border ?? this.border,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      panel: Color.lerp(panel, other.panel, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      input: Color.lerp(input, other.input, t)!,
      border: Color.lerp(border, other.border, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

TextStyle monoStyle(BuildContext context, {double size = 13}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: size,
      height: 20 / 13,
      color: Theme.of(context).colorScheme.onSurface,
    );
