import 'package:flutter/material.dart';

/// Tasarım token'ları — design/DESIGN.md
abstract final class AppColors {
  // Koyu
  static const darkBg = Color(0xFF0C0C0C);
  static const darkPanel = Color(0xFF161616);
  static const darkSidebar = Color(0xFF111111);
  static const darkHover = Color(0xFF222222);
  static const darkSelected = Color(0xFF1E3A5F);
  static const darkInput = Color(0xFF0A0A0A);

  // Aydınlık
  static const lightBg = Color(0xFFFAFAFA);
  static const lightPanel = Color(0xFFFFFFFF);
  static const lightSidebar = Color(0xFFF5F5F5);
  static const lightHover = Color(0xFFE5E5E5);
  static const lightSelected = Color(0xFFE0F2FE);
  static const lightInput = Color(0xFFFFFFFF);

  static const border = Color(0xFF2A2A2A);
  static const borderLight = Color(0xFFE5E5E5);
  static const borderFocus = Color(0xFF22D3EE);
  static const divider = Color(0xFF1F1F1F);

  static const textPrimaryDark = Color(0xFFEDEDED);
  static const textSecondaryDark = Color(0xFFA3A3A3);
  static const textMutedDark = Color(0xFF737373);

  static const textPrimaryLight = Color(0xFF171717);
  static const textSecondaryLight = Color(0xFF525252);
  static const textMutedLight = Color(0xFF737373);

  static const accent = Color(0xFF22D3EE);
  static const accentHover = Color(0xFF06B6D4);
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);
}
