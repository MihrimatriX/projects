import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renk_secici_ve_palet_uretici/domain/palette_core.dart';

void main() {
  conversionAndExportTests();

  test('orta-acik tonda koyu metin secilir', () {
    expect(PaletteCore.textColorForBg('#22C55E'), const Color(0xFF111111));
    expect(PaletteCore.textColorForBg('#1E3A8A'), const Color(0xFFFAFAFA));
  });

  test('kontrast orani AAA esigi', () {
    expect(PaletteCore.contrastRatio('#FFFFFF', '#000000'), greaterThan(20));
    final badge = PaletteCore.contrastBadge('#FFFFFF', '#000000');
    expect(badge.level, ContrastLevel.aaa);
  });

  test('harmonik palet 5 slot uretir', () {
    final colors = PaletteCore.generateHarmonicPalette(HarmonicMode.complementary);
    expect(colors.length, PaletteCore.slotCount);
    for (final hex in colors) {
      expect(hex, startsWith('#'));
      expect(hex.length, 7);
    }
  });

  test('kilitli slotlar korunur', () {
    final slots = PaletteCore.initialPalette(HarmonicMode.complementary);
    final locked = slots.map((s) => s.copyWith(locked: true)).toList();
    final regen = PaletteCore.regenerateUnlocked(locked, HarmonicMode.triadic);
    expect(regen.every((s) => s.locked), isTrue);
    expect(regen.map((s) => s.hex).toList(), slots.map((s) => s.hex).toList());
  });

  test('css export formati', () {
    final slots = [
      const PaletteSlot(hex: '#A855F7'),
      const PaletteSlot(hex: '#22C55E'),
    ];
    final css = PaletteCore.exportCss(slots);
    expect(css, contains('--palette-1: #A855F7'));
    expect(css, contains('--palette-2: #22C55E'));
  });
}

void conversionAndExportTests() {
  test('normalizeHex kisa/uzun/bosluklu bicimleri kabul eder, gecersizi reddeder', () {
    expect(PaletteCore.normalizeHex('#38f'), '#3388FF');
    expect(PaletteCore.normalizeHex(' 3b82f6 '), '#3B82F6');
    expect(PaletteCore.normalizeHex('#12345'), isNull);
    expect(PaletteCore.normalizeHex('#GGGGGG'), isNull);
    expect(PaletteCore.normalizeHex(''), isNull);
    expect(() => PaletteCore.hexToRgb('zzz'), throwsFormatException);
  });

  test('HEX <-> RGB <-> HSL bilinen degerler', () {
    expect(PaletteCore.hexToRgb('#3B82F6'), (r: 59, g: 130, b: 246));
    expect(PaletteCore.rgbToHex(300, -5, 128), '#FF0080');
    expect(PaletteCore.hexToHsl('#FF0000'), (h: 0, s: 100, l: 50));
    expect(PaletteCore.hexToHsl('#808080').s, 0);
    expect(PaletteCore.hslColor(120, 100, 25), '#008000');
    expect(PaletteCore.hslColor(-120, 100, 50), '#0000FF');
    expect(PaletteCore.colorToHex(PaletteCore.hexToColor('#A855F7')), '#A855F7');
  });

  test('kontrast WCAG esikleri ve asagi yuvarlanan oran', () {
    expect(PaletteCore.contrastRatio('#FFFFFF', '#000000'), closeTo(21, 0.001));
    expect(PaletteCore.contrastRatio('#000000', '#FFFFFF'), closeTo(21, 0.001));
    // #777 beyaza karsi ~4.48: AA'yi gecmez ve "4.5" gibi gosterilmez.
    final grey = PaletteCore.contrastBadge('#777777', '#FFFFFF');
    expect(grey.level, ContrastLevel.warn);
    expect(grey.ratio, '4.4');
    expect(PaletteCore.contrastBadge('#767676', '#FFFFFF').level, ContrastLevel.aa);
    expect(PaletteCore.contrastBadge('#FFFFFF', '#FFFFFF').level, ContrastLevel.fail);
  });

  group('disa aktarma bicimleri', () {
    const slots = [PaletteSlot(hex: '#A855F7'), PaletteSlot(hex: '#22C55E')];

    test('scss degiskenleri', () {
      expect(PaletteCore.export('scss', slots), '\$palette-1: #A855F7;\n\$palette-2: #22C55E;');
    });

    test('tailwind', () {
      final tw = PaletteCore.export('tailwind', slots);
      expect(tw, contains("palette1: '#A855F7',"));
      expect(tw, startsWith('module.exports'));
    });

    test('json gecerli ve rgb/hsl icerir; uyari yorumu eklenmez', () {
      final out = PaletteCore.export('json', slots, warning: 'dusuk kontrast');
      final map = jsonDecode(out) as Map<String, dynamic>;
      expect(map['palette-1']['hex'], '#A855F7');
      expect(map['palette-2']['rgb'], [34, 197, 94]);
      expect((map['palette-1']['hsl'] as List).length, 3);
    });

    test('uyari css/scss/tailwind basina yorum olarak eklenir', () {
      for (final f in ['css', 'scss', 'tailwind']) {
        expect(PaletteCore.export(f, slots, warning: 'dusuk'), startsWith('/* dusuk */\n'));
      }
    });

    test('her bicim sekmesi tanimli', () {
      expect(PaletteCore.exportFormats.keys, ['css', 'scss', 'tailwind', 'json']);
    });
  });
}
