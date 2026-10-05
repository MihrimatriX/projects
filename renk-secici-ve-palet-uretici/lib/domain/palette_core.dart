import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

enum HarmonicMode { complementary, analogous, triadic }

enum ContrastLevel { aaa, aa, warn, fail }

class PaletteSlot {
  const PaletteSlot({required this.hex, this.locked = false});

  final String hex;
  final bool locked;

  PaletteSlot copyWith({String? hex, bool? locked}) => PaletteSlot(
        hex: hex ?? this.hex,
        locked: locked ?? this.locked,
      );
}

class ContrastBadge {
  const ContrastBadge({required this.level, required this.label, required this.ratio});

  final ContrastLevel level;
  final String label;
  final String ratio;
}

class ExtractedTheme {
  const ExtractedTheme({
    required this.bgApp,
    required this.bgPanel,
    required this.bgElevated,
    required this.bgHover,
    required this.border,
    required this.borderFocus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.isDark,
  });

  final Color bgApp;
  final Color bgPanel;
  final Color bgElevated;
  final Color bgHover;
  final Color border;
  final Color borderFocus;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final bool isDark;
}

class ExtractResult {
  const ExtractResult({required this.palette, this.theme});

  final List<String> palette;
  final ExtractedTheme? theme;
}

abstract final class PaletteCore {
  static const slotCount = 5;
  static final _rng = math.Random();

  static int _clamp(int n, int min, int max) => n < min ? min : (n > max ? max : n);

  static final _hexPattern = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');

  /// Kullanıcı girdisini `#RRGGBB` biçimine getirir; geçersizse null.
  /// Kabul: `#abc`, `abc`, `#aabbcc`, `aabbcc` (baştaki/sondaki boşluk yok sayılır).
  static String? normalizeHex(String input) {
    final m = _hexPattern.firstMatch(input.trim());
    if (m == null) return null;
    var h = m.group(1)!;
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    return '#${h.toUpperCase()}';
  }

  static ({int r, int g, int b}) hexToRgb(String hex) {
    final norm = normalizeHex(hex);
    if (norm == null) throw FormatException('Geçersiz HEX renk', hex);
    final h = norm.substring(1);
    return (
      r: int.parse(h.substring(0, 2), radix: 16),
      g: int.parse(h.substring(2, 4), radix: 16),
      b: int.parse(h.substring(4, 6), radix: 16),
    );
  }

  static String rgbToHex(int r, int g, int b) {
    String p(int v) => _clamp(v, 0, 255).toRadixString(16).padLeft(2, '0');
    return '#${p(r)}${p(g)}${p(b)}'.toUpperCase();
  }

  static Color hexToColor(String hex) {
    final rgb = hexToRgb(hex);
    return Color.fromARGB(255, rgb.r, rgb.g, rgb.b);
  }

  static String colorToHex(Color c) {
    return rgbToHex((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());
  }

  static ({int h, int s, int l}) hexToHsl(String hex) {
    final rgb = hexToRgb(hex);
    return _rgbToHsl(rgb.r, rgb.g, rgb.b);
  }

  static ({int h, int s, int l}) _rgbToHsl(int r, int g, int b) {
    final rf = r / 255, gf = g / 255, bf = b / 255;
    final max = math.max(rf, math.max(gf, bf));
    final min = math.min(rf, math.min(gf, bf));
    var h = 0.0;
    var s = 0.0;
    final l = (max + min) / 2;
    if (max != min) {
      final d = max - min;
      s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
      if (max == rf) {
        h = ((gf - bf) / d + (gf < bf ? 6 : 0)) / 6;
      } else if (max == gf) {
        h = ((bf - rf) / d + 2) / 6;
      } else {
        h = ((rf - gf) / d + 4) / 6;
      }
    }
    return (h: (h * 360).round(), s: (s * 100).round(), l: (l * 100).round());
  }

  static ({int r, int g, int b}) _hslToRgb(int h, int s, int l) {
    h = ((h % 360) + 360) % 360;
    final sf = s / 100;
    final lf = l / 100;
    final c = (1 - (2 * lf - 1).abs()) * sf;
    final x = c * (1 - (((h / 60) % 2) - 1).abs());
    final m = lf - c / 2;
    double r = 0, g = 0, b = 0;
    if (h < 60) {
      r = c;
      g = x;
    } else if (h < 120) {
      r = x;
      g = c;
    } else if (h < 180) {
      g = c;
      b = x;
    } else if (h < 240) {
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      b = c;
    } else {
      r = c;
      b = x;
    }
    return (
      r: ((r + m) * 255).round(),
      g: ((g + m) * 255).round(),
      b: ((b + m) * 255).round(),
    );
  }

  static String hslColor(int h, int s, int l) {
    final rgb = _hslToRgb(h, s, l);
    return rgbToHex(rgb.r, rgb.g, rgb.b);
  }

  static double _relativeLuminance(int r, int g, int b) {
    double ch(double x) =>
        x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
    final rf = ch(r / 255), gf = ch(g / 255), bf = ch(b / 255);
    return 0.2126 * rf + 0.7152 * gf + 0.0722 * bf;
  }

  static double contrastRatio(String hex1, String hex2) {
    final c1 = hexToRgb(hex1);
    final c2 = hexToRgb(hex2);
    final l1 = _relativeLuminance(c1.r, c1.g, c1.b);
    final l2 = _relativeLuminance(c2.r, c2.g, c2.b);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color textColorForBg(String hex) {
    final rgb = hexToRgb(hex);
    // ~0.18 luminans, #111 ve #FAFAFA metinlerin kontrastının eşitlendiği noktadır;
    // üstünde koyu metin daha okunaklı. (0.45 eşiği orta tonlarda ~2:1 kontrast veriyordu.)
    return _relativeLuminance(rgb.r, rgb.g, rgb.b) > 0.18
        ? const Color(0xFF111111)
        : const Color(0xFFFAFAFA);
  }

  static ContrastBadge contrastBadge(String hex, String baseHex) {
    // Aşağı yuvarlanır: 4.47 "4.5" görünüp AA'yı geçmiş gibi durmasın.
    final ratio = (contrastRatio(hex, baseHex) * 10).floor() / 10;
    if (ratio >= 7) {
      return ContrastBadge(level: ContrastLevel.aaa, label: 'AAA', ratio: ratio.toStringAsFixed(1));
    }
    if (ratio >= 4.5) {
      return ContrastBadge(level: ContrastLevel.aa, label: 'AA', ratio: ratio.toStringAsFixed(1));
    }
    if (ratio >= 3) {
      return ContrastBadge(level: ContrastLevel.warn, label: 'Düşük', ratio: ratio.toStringAsFixed(1));
    }
    return ContrastBadge(level: ContrastLevel.fail, label: 'Başarısız', ratio: ratio.toStringAsFixed(1));
  }

  // Rastgele bir taban ton seçilir; moda göre renk çarkında sabit açılarla
  // (tamamlayıcı ±180°, analog ±15/30°, üçlü 120/240°) kaydırılıp HSL'den HEX'e çevrilir.
  static List<String> generateHarmonicPalette(HarmonicMode mode, {int count = slotCount}) {
    final baseHue = _rng.nextInt(360);
    final hues = switch (mode) {
      HarmonicMode.complementary => [baseHue, baseHue + 180, baseHue + 30, baseHue + 150, baseHue + 210],
      HarmonicMode.analogous => [baseHue - 30, baseHue - 15, baseHue, baseHue + 15, baseHue + 30],
      HarmonicMode.triadic => [baseHue, baseHue + 120, baseHue + 240, baseHue + 60, baseHue + 180],
    };
    const saturations = [72, 65, 58, 80, 55];
    const lightnesses = [42, 48, 54, 38, 62];
    return List.generate(count, (i) {
      return hslColor(hues[i % hues.length], saturations[i % saturations.length], lightnesses[i % lightnesses.length]);
    });
  }

  static List<PaletteSlot> initialPalette(HarmonicMode mode) {
    return generateHarmonicPalette(mode)
        .asMap()
        .entries
        .map((e) => PaletteSlot(hex: e.value, locked: e.key == 0))
        .toList();
  }

  static List<PaletteSlot> regenerateUnlocked(List<PaletteSlot> slots, HarmonicMode mode) {
    final fresh = generateHarmonicPalette(mode, count: slots.length);
    var fi = 0;
    return slots.map((slot) {
      if (slot.locked) return slot;
      return PaletteSlot(hex: fresh[fi++], locked: false);
    }).toList();
  }

  static List<PaletteSlot> applyColorsToSlots(List<PaletteSlot> slots, List<String> colors) {
    var ci = 0;
    return slots.map((slot) {
      if (slot.locked) return slot;
      if (ci >= colors.length) return slot;
      return PaletteSlot(hex: colors[ci++], locked: false);
    }).toList();
  }

  static String exportCss(List<PaletteSlot> slots) {
    final lines = <String>[':root {'];
    for (var i = 0; i < slots.length; i++) {
      lines.add('  --palette-${i + 1}: ${slots[i].hex};');
    }
    lines.add('}');
    return lines.join('\n');
  }

  static String exportTailwind(List<PaletteSlot> slots) {
    final lines = <String>[
      'module.exports = {',
      '  theme: {',
      '    extend: {',
      '      colors: {',
    ];
    for (var i = 0; i < slots.length; i++) {
      lines.add("        palette${i + 1}: '${slots[i].hex}',");
    }
    lines.addAll(['      }', '    }', '  }', '};']);
    return lines.join('\n');
  }

  static const exportFormats = {
    'css': 'CSS :root',
    'scss': 'SCSS',
    'tailwind': 'Tailwind',
    'json': 'JSON',
  };

  static String exportScss(List<PaletteSlot> slots) => [
        for (var i = 0; i < slots.length; i++) '\$palette-${i + 1}: ${slots[i].hex};',
      ].join('\n');

  /// Tasarım token'ı olarak JSON (hex, rgb, hsl).
  static String exportJson(List<PaletteSlot> slots) {
    final map = <String, Object>{};
    for (var i = 0; i < slots.length; i++) {
      final rgb = hexToRgb(slots[i].hex);
      final hsl = hexToHsl(slots[i].hex);
      map['palette-${i + 1}'] = {
        'hex': slots[i].hex,
        'rgb': [rgb.r, rgb.g, rgb.b],
        'hsl': [hsl.h, hsl.s, hsl.l],
      };
    }
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// [format]: [exportFormats] anahtarı. [warning] biçimin yorum söz dizimiyle
  /// başa eklenir; JSON yorum desteklemediği için orada eklenmez.
  static String export(String format, List<PaletteSlot> slots, {String? warning}) {
    final code = switch (format) {
      'scss' => exportScss(slots),
      'tailwind' => exportTailwind(slots),
      'json' => exportJson(slots),
      _ => exportCss(slots),
    };
    if (warning == null || format == 'json') return code;
    return '/* $warning */\n$code';
  }

  static String _adjustHexLightness(String hex, int delta) {
    final hsl = hexToHsl(hex);
    return hslColor(hsl.h, hsl.s, _clamp(hsl.l + delta, 4, 96));
  }

  static String _mixHex(String hex1, String hex2, double t) {
    final a = hexToRgb(hex1);
    final b = hexToRgb(hex2);
    return rgbToHex(
      (a.r + (b.r - a.r) * t).round(),
      (a.g + (b.g - a.g) * t).round(),
      (a.b + (b.b - a.b) * t).round(),
    );
  }

  static int _colorSaturation(String hex) => hexToHsl(hex).s;

  static String _mostSaturatedColor(List<String> colors, {int minSat = 18}) {
    String? best;
    var bestSat = -1;
    for (final hex in colors) {
      final sat = _colorSaturation(hex);
      if (sat >= minSat && sat > bestSat) {
        bestSat = sat;
        best = hex;
      }
    }
    return best ?? colors[colors.length ~/ 2];
  }

  static List<String> _sortColorsByLuminance(List<String> colors) {
    final copy = colors.toList()
      ..sort((a, b) {
        final ra = hexToRgb(a);
        final rb = hexToRgb(b);
        final la = _relativeLuminance(ra.r, ra.g, ra.b);
        final lb = _relativeLuminance(rb.r, rb.g, rb.b);
        return lb.compareTo(la);
      });
    return copy;
  }

  static int _colorDistSq(({int r, int g, int b}) a, ({int r, int g, int b}) b) {
    return (a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b);
  }

  static List<String> _kMeansColors(List<({int r, int g, int b})> pixels, int count) {
    if (pixels.isEmpty) return [];
    if (pixels.length < count) {
      return pixels.map((p) => rgbToHex(p.r, p.g, p.b)).toList();
    }

    final centroids = <({int r, int g, int b})>[];
    final used = <int>{};
    while (centroids.length < count) {
      final idx = _rng.nextInt(pixels.length);
      if (used.contains(idx)) continue;
      used.add(idx);
      centroids.add(pixels[idx]);
    }

    for (var iter = 0; iter < 12; iter++) {
      final clusters = List<List<({int r, int g, int b})>>.generate(count, (_) => []);
      for (final p in pixels) {
        var minDist = double.infinity;
        var minIdx = 0;
        for (var ci = 0; ci < centroids.length; ci++) {
          final d = _colorDistSq(p, centroids[ci]).toDouble();
          if (d < minDist) {
            minDist = d;
            minIdx = ci;
          }
        }
        clusters[minIdx].add(p);
      }
      for (var i = 0; i < count; i++) {
        final cluster = clusters[i];
        if (cluster.isEmpty) continue;
        var r = 0, g = 0, b = 0;
        for (final p in cluster) {
          r += p.r;
          g += p.g;
          b += p.b;
        }
        centroids[i] = (r: r ~/ cluster.length, g: g ~/ cluster.length, b: b ~/ cluster.length);
      }
    }
    return centroids.map((c) => rgbToHex(c.r, c.g, c.b)).toList();
  }

  static List<({int r, int g, int b})> _samplePixels(img.Image image) {
    final pixels = <({int r, int g, int b})>[];
    const step = 2;
    for (var y = 0; y < image.height; y += step) {
      for (var x = 0; x < image.width; x += step) {
        final p = image.getPixel(x, y);
        final a = p.a.toInt();
        if (a < 128) continue;
        final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
        final lum = _relativeLuminance(r, g, b);
        if (lum > 0.97 || lum < 0.03) continue;
        pixels.add((r: r, g: g, b: b));
      }
    }
    return pixels;
  }

  // Görsel ≤140 px'e küçültülür, şeffaf/çok açık/çok koyu pikseller atılır ve
  // kalanlar RGB uzayında k-means (12 tur) ile `count` kümeye ayrılır; küme merkezleri palet olur.
  static List<String> extractPaletteFromBytes(Uint8List bytes, {int count = slotCount}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];

    const maxDim = 140;
    final w = decoded.width;
    final h = decoded.height;
    final scale = math.min(1.0, maxDim / math.max(w, h));
    final cw = math.max(1, (w * scale).round());
    final ch = math.max(1, (h * scale).round());
    final resized = img.copyResize(decoded, width: cw, height: ch);

    var pixels = _samplePixels(resized);
    if (pixels.length < count) {
      pixels = [];
      for (var y = 0; y < resized.height; y++) {
        for (var x = 0; x < resized.width; x++) {
          final p = resized.getPixel(x, y);
          pixels.add((r: p.r.toInt(), g: p.g.toInt(), b: p.b.toInt()));
        }
      }
    }
    return _sortColorsByLuminance(_kMeansColors(pixels, count));
  }

  static String? _averageImageColor(img.Image image) {
    const maxDim = 64;
    final scale = math.min(1.0, maxDim / math.max(image.width, image.height));
    final cw = math.max(1, (image.width * scale).round());
    final ch = math.max(1, (image.height * scale).round());
    final small = img.copyResize(image, width: cw, height: ch);
    var r = 0, g = 0, b = 0, n = 0;
    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        final p = small.getPixel(x, y);
        if (p.a.toInt() < 128) continue;
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        n++;
      }
    }
    if (n == 0) return null;
    return rgbToHex(r ~/ n, g ~/ n, b ~/ n);
  }

  static ExtractedTheme? extractThemeFromImage(img.Image image, List<String> paletteColors) {
    if (paletteColors.isEmpty) return null;

    final sorted = _sortColorsByLuminance(paletteColors);
    final avgHex = _averageImageColor(image) ?? sorted[sorted.length ~/ 2];
    final avgLum = _relativeLuminance(hexToRgb(avgHex).r, hexToRgb(avgHex).g, hexToRgb(avgHex).b);
    final isDark = avgLum < 0.42;

    final bgApp = isDark
        ? _adjustHexLightness(sorted[0], -4)
        : _adjustHexLightness(sorted.last, 6);
    final bgPanel = isDark
        ? _mixHex(bgApp, sorted.length > 1 ? sorted[1] : avgHex, 0.22)
        : _mixHex(bgApp, sorted.length > 2 ? sorted[sorted.length - 2] : avgHex, 0.18);
    final bgElevated = isDark
        ? _mixHex(bgPanel, sorted.length > 2 ? sorted[2] : sorted[1], 0.35)
        : _mixHex(bgPanel, '#FFFFFF', 0.55);
    final bgHover = isDark
        ? _mixHex(bgElevated, sorted.length > 2 ? sorted[2] : avgHex, 0.42)
        : _mixHex(bgElevated, '#000000', 0.06);

    var accent = _mostSaturatedColor(paletteColors);
    if (contrastRatio(accent, bgApp) < 3) {
      for (final c in paletteColors) {
        if (c != accent && contrastRatio(c, bgApp) >= 3 && _colorSaturation(c) >= 20) {
          accent = c;
          break;
        }
      }
    }

    final textPrimary = isDark ? '#FAFAFA' : '#111111';
    final textSecondary = isDark ? _mixHex(textPrimary, bgApp, 0.38) : _mixHex(textPrimary, bgApp, 0.45);
    final textMuted = isDark ? _mixHex(textPrimary, bgApp, 0.58) : _mixHex(textPrimary, bgApp, 0.62);
    final border = isDark ? _mixHex(bgApp, '#FFFFFF', 0.14) : _mixHex(bgApp, '#000000', 0.12);

    return ExtractedTheme(
      bgApp: hexToColor(bgApp),
      bgPanel: hexToColor(bgPanel),
      bgElevated: hexToColor(bgElevated),
      bgHover: hexToColor(bgHover),
      border: hexToColor(border),
      borderFocus: hexToColor(accent),
      textPrimary: hexToColor(textPrimary),
      textSecondary: hexToColor(textSecondary),
      textMuted: hexToColor(textMuted),
      accent: hexToColor(accent),
      isDark: isDark,
    );
  }

  static ExtractResult extractThemeAndPalette(Uint8List bytes, {int count = slotCount}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return const ExtractResult(palette: []);
    final palette = extractPaletteFromBytes(bytes, count: count);
    final theme = extractThemeFromImage(decoded, palette);
    return ExtractResult(palette: palette, theme: theme);
  }

  static String paletteSignature(List<PaletteSlot> slots) =>
      slots.map((s) => s.hex).join('|');
}
