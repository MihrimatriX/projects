import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class ContrastUtils {
  static double _linearize(int channel) {
    final c = channel / 255.0;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  static double luminance(Color color) {
    final r = _linearize((color.r * 255).round());
    final g = _linearize((color.g * 255).round());
    final b = _linearize((color.b * 255).round());
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double contrastRatio(Color a, Color b) {
    final l1 = luminance(a);
    final l2 = luminance(b);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = lighter == l1 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static bool hasReadableQrContrast(Color foreground, Color background) =>
      contrastRatio(foreground, background) >= 4.5;
}
