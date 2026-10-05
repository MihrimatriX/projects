import 'package:flutter/material.dart';

/// design/css/tokens.css
abstract final class AppColors {
  static const bgApp = Color(0xFF1A1D23);
  static const bgSurface = Color(0xFF242830);
  static const bgHover = Color(0xFF2D323C);
  static const bgElevated = Color(0xFF323845);
  static const border = Color(0xFF3D4450);
  static const borderFocus = Color(0xFF14B8A6);
  static const textPrimary = Color(0xFFF0F2F5);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);
  static const accent = Color(0xFF14B8A6);
  static const accentHover = Color(0xFF0D9488);
  static const accentSoft = Color(0x2614B8A6);
  static const pomodoro = Color(0xFFF97316);
  static const pomodoroSoft = Color(0x26F97316);
  static const success = Color(0xFF22C55E);
  static const danger = Color(0xFFEF4444);
  static const warn = Color(0xFFFFAD1F);

  static const chart = [accent, Color(0xFF818CF8), pomodoro, Color(0xFFA78BFA), Color(0xFF34D399)];

  static Color projectColor(int? argb, int index) {
    if (argb != null && argb != 0) return Color(argb);
    return chart[index % chart.length];
  }
}
