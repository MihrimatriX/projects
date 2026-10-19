import 'package:flutter/material.dart';

/// Tasarım token'ları — design/DESIGN.md
abstract final class AppColors {
  // Aydınlık
  static const lightBg = Color(0xFFFAFAFA);
  static const lightSidebar = Color(0xFFFFFFFF);
  static const lightHover = Color(0xFFF4F4F5);
  static const lightSelected = Color(0xFFEFF6FF);
  static const lightCard = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4E7);
  static const textPrimary = Color(0xFF18181B);
  static const textSecondary = Color(0xFF52525B);
  static const textMuted = Color(0xFFA1A1AA);
  static const accent = Color(0xFF2563EB);
  static const accentSoft = Color(0xFFDBEAFE);
  static const accentHover = Color(0xFF1D4ED8);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const priorityLow = Color(0xFF94A3B8);

  // Koyu
  static const darkBg = Color(0xFF09090B);
  static const darkSidebar = Color(0xFF18181B);
  static const darkHover = Color(0xFF27272A);
  static const darkSelected = Color(0xFF1E3A5F);
  static const darkBorder = Color(0xFF3F3F46);
  static const darkTextPrimary = Color(0xFFFAFAFA);
  static const darkTextSecondary = Color(0xFFD4D4D8);
  static const darkCard = Color(0xFF18181B);
  static const darkAccentSoft = Color(0x332563EB);

  static const detailPanelWidth = 380.0;

  static const projectColors = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  static Color projectColor(int index) =>
      projectColors[index % projectColors.length];

  static Color borderFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : border;

  static Color hoverFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkHover : lightHover;

  static Color selectedFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSelected : lightSelected;

  static Color sidebarFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkSidebar : lightSidebar;

  static Color primaryTextFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextPrimary : textPrimary;

  static Color secondaryTextFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color cardFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : lightCard;

  static Color accentSoftFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkAccentSoft : accentSoft;

  static List<BoxShadow> cardShadow(Brightness brightness) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: brightness == Brightness.dark ? 0.25 : 0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

}

abstract final class AppLayout {
  static const sidebarWidth = 260.0;
  static const bottomNavHeight = 56.0;
  static const taskRowMinHeight = 44.0;
  static const pagePaddingH = 32.0;
  static const pagePaddingV = 24.0;
  static const radius = 8.0;
  static const radiusSm = 6.0;
  static const radiusChip = 12.0;

  static const breakpointWide = 900.0;
  static const breakpointDrawer = 600.0;
}
