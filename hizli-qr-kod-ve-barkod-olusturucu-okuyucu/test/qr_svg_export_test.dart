import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/qr_svg_export.dart';
import 'package:qr/qr.dart';

void main() {
  test('buildSvg contains svg root and data modules', () {
    final svg = QrSvgExport.buildSvg(
      data: 'https://example.com',
      foreground: Colors.black,
      background: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    expect(svg, contains('<svg'));
    expect(svg, contains('</svg>'));
    expect(svg, contains('#000000'));
    expect(svg, contains('#ffffff'));
    expect(svg.split('<rect').length, greaterThan(10));
  });
}
