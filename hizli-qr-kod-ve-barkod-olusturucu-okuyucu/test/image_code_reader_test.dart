import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/barcode_utils.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/image_code_reader.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/qr_export.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/qr_presets.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// `barcode` paketinin çubuklarını beyaz zemine çizer (sessiz bölgeli).
({Uint8List rgba, int w, int h}) rasterBarcode(Barcode bc, String data,
    {int w = 420, int h = 120}) {
  final rgba = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
  const margin = 40;
  for (final e in bc.make(data,
      width: (w - 2 * margin).toDouble(), height: h - 20.0, drawText: false)) {
    if (e is! BarcodeBar || !e.black) continue;
    final x0 = (e.left + margin).round();
    final x1 = (e.left + e.width + margin).round();
    for (var y = (e.top + 10).round();
        y < (e.top + e.height + 10).round();
        y++) {
      for (var x = x0; x < x1; x++) {
        final p = (y * w + x) * 4;
        rgba[p] = rgba[p + 1] = rgba[p + 2] = 0;
      }
    }
  }
  return (rgba: rgba, w: w, h: h);
}

/// 90° saat yönünde döndürür (dikey barkod).
({Uint8List rgba, int w, int h}) rotate90(
    ({Uint8List rgba, int w, int h}) img) {
  final out = Uint8List(img.rgba.length);
  final nw = img.h, nh = img.w;
  for (var y = 0; y < img.h; y++) {
    for (var x = 0; x < img.w; x++) {
      final src = (y * img.w + x) * 4;
      final dst = (x * nw + (nw - 1 - y)) * 4;
      out.setRange(dst, dst + 4, img.rgba, src);
    }
  }
  return (rgba: out, w: nw, h: nh);
}

Future<Uint8List> encodePng(Uint8List rgba, int w, int h) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
  final desc = ui.ImageDescriptor.raw(buffer,
      width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
  final image = (await (await desc.instantiateCodec()).getNextFrame()).image;
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}

void main() {
  group('QR: üretilen PNG aynı içeriğe geri çözülür', () {
    final contents = <String, String>{
      'URL': QrPresets.url('ornek.com/kampanya?id=42&x=y'),
      'Türkçe metin': 'Merhaba dünya — ğüşıöç İĞÜŞÖÇ 😀',
      'Wi-Fi': QrPresets.wifi(
          ssid: 'Ev;Ağı', password: r'p@ss,w\rd', encryption: 'WPA'),
      'vCard': QrPresets.vcard(
          name: 'Ayşe Yılmaz',
          phone: '+90 555 000 00 00',
          email: 'ayse@ornek.com'),
      'uzun metin': List.generate(30, (i) => 'satır $i').join('\n'),
    };
    for (final entry in contents.entries) {
      testWidgets(entry.key, (tester) async {
        await tester.runAsync(() async {
          for (final (ecc, size) in [
            (QrErrorCorrectLevel.L, 512),
            (QrErrorCorrectLevel.M, 1024),
            (QrErrorCorrectLevel.H, 360),
          ]) {
            final png = await QrExport.renderPng(
              data: entry.value,
              size: size,
              foreground: const Color(0xFF111111),
              background: const Color(0xFFFFFFFF),
              errorCorrectionLevel: ecc,
            );
            final decoded = await ImageCodeReader.decodeImageBytes(png!);
            expect(decoded?.text, entry.value, reason: 'ECC $ecc, $size px');
            expect(decoded?.format, 'qrCode');
          }
        });
      });
    }

    testWidgets('ortasında logo olan QR (H düzeyi) okunur', (tester) async {
      await tester.runAsync(() async {
        const s = 64;
        final logo = Uint8List(s * s * 4);
        for (var p = 0; p < logo.length; p += 4) {
          logo[p] = 220;
          logo[p + 3] = 255;
        }
        final png = await QrExport.renderPng(
          data: 'https://ornek.com/logo',
          size: 512,
          foreground: Colors.black,
          background: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
          logoBytes: await encodePng(logo, s, s),
          logoScale: 0.2,
        );
        expect((await ImageCodeReader.decodeImageBytes(png!))?.text,
            'https://ornek.com/logo');
      });
    });

    testWidgets('açık renk QR koyu zeminde (ters) de okunur', (tester) async {
      await tester.runAsync(() async {
        final png = await QrExport.renderPng(
          data: 'ters renk',
          size: 300,
          foreground: Colors.white,
          background: const Color(0xFF101418),
          errorCorrectionLevel: QrErrorCorrectLevel.M,
        );
        expect(
            (await ImageCodeReader.decodeImageBytes(png!))?.text, 'ters renk');
      });
    });
  });

  group('barkod: üretilen çubuklar aynı içeriğe geri çözülür', () {
    for (final data in [
      'ABC-123',
      'hello world',
      '1234567890',
      'AB12345678cd',
      'x'
    ]) {
      test('Code128 "$data"', () {
        final img = rasterBarcode(Barcode.code128(), data);
        final r = ImageCodeReader.decodeRgba(img.rgba, img.w, img.h);
        expect(r?.text, data);
        expect(r?.format, 'code128');
      });
    }

    for (final raw in [
      '869063200123',
      '4006381333931',
      '0000000000000',
      '590123412345'
    ]) {
      test('EAN-13 $raw', () {
        final code = BarcodeUtils.normalize(AppBarcodeType.ean13, raw);
        final img = rasterBarcode(Barcode.ean13(), code);
        final r = ImageCodeReader.decodeRgba(img.rgba, img.w, img.h);
        expect(r?.text, code);
        expect(r?.format, 'ean13');
      });
    }

    test('dikey (90°) ve ters çevrilmiş barkod', () {
      final img = rotate90(rasterBarcode(Barcode.code128(), 'DIKEY-42'));
      expect(
          ImageCodeReader.decodeRgba(img.rgba, img.w, img.h)?.text, 'DIKEY-42');
      final upside =
          rotate90(rotate90(rasterBarcode(Barcode.ean13(), '4006381333931')));
      expect(ImageCodeReader.decodeRgba(upside.rgba, upside.w, upside.h)?.text,
          '4006381333931');
    });

    testWidgets('PNG dosyası üzerinden (uygulamadaki BarcodeWidget çizimi)',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24),
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: 'Siparis-2026/10',
                  width: 300,
                  height: 90,
                  drawText: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final png = (await image.toByteData(format: ui.ImageByteFormat.png))!
            .buffer
            .asUint8List();
        final r = await ImageCodeReader.decodeImageBytes(png);
        expect(r?.text, 'Siparis-2026/10');
      });
    });
  });

  group('okunamayan girdiler', () {
    test('boş ve gürültülü görselde kod yok', () {
      const w = 200, h = 120;
      final white = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
      expect(ImageCodeReader.decodeRgba(white, w, h), isNull);
      final rnd = Random(7);
      final noise = Uint8List.fromList(
          List.generate(w * h * 4, (i) => i % 4 == 3 ? 255 : rnd.nextInt(256)));
      expect(ImageCodeReader.decodeRgba(noise, w, h), isNull);
    });

    test('bozulmuş EAN-13 sağlaması reddedilir', () {
      final img = rasterBarcode(Barcode.ean13(), '4006381333931');
      // Ortadaki bir sütunu tamamen beyazla: çubuklar bozulur.
      for (var y = 0; y < img.h; y++) {
        for (var x = 200; x < 206; x++) {
          final p = (y * img.w + x) * 4;
          img.rgba[p] = img.rgba[p + 1] = img.rgba[p + 2] = 255;
        }
      }
      final r = ImageCodeReader.decodeRgba(img.rgba, img.w, img.h);
      expect(r?.text, isNot('4006381333931'.replaceRange(6, 7, '9')));
      if (r != null) expect(r.text, '4006381333931');
    });

    testWidgets('görsel olmayan bayt dizisi anlaşılır hata verir',
        (tester) async {
      await tester.runAsync(() async {
        await expectLater(
          ImageCodeReader.decodeImageBytes(Uint8List.fromList([1, 2, 3, 4])),
          throwsA(isA<FormatException>()),
        );
      });
    });

    testWidgets('PNG ile kodlanan saydam zeminli barkod okunur',
        (tester) async {
      await tester.runAsync(() async {
        final img = rasterBarcode(Barcode.code128(), 'SAYDAM');
        // Beyaz pikselleri saydam yap.
        for (var p = 0; p < img.rgba.length; p += 4) {
          if (img.rgba[p] == 255) img.rgba[p + 3] = 0;
        }
        final png = await encodePng(img.rgba, img.w, img.h);
        expect((await ImageCodeReader.decodeImageBytes(png))?.text, 'SAYDAM');
      });
    });
  });
}
