import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:zxing2/qrcode.dart';

DecodedCode? _decodeRgbaJob((Uint8List, int, int) job) =>
    ImageCodeReader.decodeRgba(job.$1, job.$2, job.$3);

/// Görselden okunan kod.
class DecodedCode {
  const DecodedCode(this.text, this.format);

  final String text;

  /// Kullanıcıya gösterilen biçim adı: `qrCode`, `code128`, `ean13`.
  final String format;

  @override
  String toString() => '$format: $text';
}

/// Görsel dosyasından (PNG/JPG/GIF/BMP/WebP) QR, Code128 ve EAN-13 okur.
///
/// Tamamen Dart: kamera eklentisi olmayan platformlarda (Windows, web) da
/// çalışır. Görsel `dart:ui` ile çözülür; QR için zxing2, 1B barkodlar için
/// aşağıdaki satır tarayıcı kullanılır (uygulamanın ürettiği iki barkod türü).
abstract final class ImageCodeReader {
  /// Büyük fotoğraflar bu genişliğe küçültülür (Dart'ta zxing yavaş).
  static const maxSide = 1600;

  static Future<DecodedCode?> decodeImageBytes(Uint8List bytes) async {
    final ui.Image image;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      final scale = (w > h ? w : h) > maxSide ? maxSide / (w > h ? w : h) : 1.0;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (w * scale).round(),
        targetHeight: (h * scale).round(),
      );
      image = (await codec.getNextFrame()).image;
    } catch (_) {
      throw const FormatException(
          'Görsel açılamadı (desteklenen: PNG, JPG, GIF, BMP, WebP).');
    }
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      // Çözme CPU yoğun (büyük fotoğrafta saniyeler): arayüz donmasın diye ayrı isolate.
      return await compute(_decodeRgbaJob, (data.buffer.asUint8List(), image.width, image.height));
    } finally {
      image.dispose();
    }
  }

  /// RGBA piksellerinden kod okur. Saydam pikseller beyaz kabul edilir.
  static DecodedCode? decodeRgba(Uint8List rgba, int width, int height) {
    final lum = Uint8List(width * height);
    for (var i = 0, p = 0; i < lum.length; i++, p += 4) {
      final a = rgba[p + 3];
      final y = (rgba[p] * 299 + rgba[p + 1] * 587 + rgba[p + 2] * 114) ~/ 1000;
      // Saydam alanı beyazla birleştir (PNG dışa aktarmaları saydam olabilir).
      lum[i] = (y * a + 255 * (255 - a)) ~/ 255;
    }
    return decodeLuminance(lum, width, height);
  }

  static DecodedCode? decodeLuminance(Uint8List lum, int width, int height) {
    return _decodeQr(lum, width, height) ??
        LinearBarcodeScanner.scan(lum, width, height);
  }

  static DecodedCode? _decodeQr(Uint8List lum, int width, int height) {
    // Kenarına kadar kırpılmış QR'larda (sessiz bölge yok) bulucu desenler
    // algılanamıyor; görseli açık renkli bir kenarlıkla genişlet.
    final border = (width > height ? width : height) ~/ 12 + 8;
    final pw = width + 2 * border;
    final ph = height + 2 * border;
    final pixels = Int32List(pw * ph)..fillRange(0, pw * ph, 0xFFFFFFFF);
    // Ters renkli görsellerde kenarlık da tersine (koyu) olmalı: kenar ortalamasına bak.
    var edgeSum = 0;
    for (var x = 0; x < width; x++) {
      edgeSum += lum[x] + lum[(height - 1) * width + x];
    }
    if (edgeSum ~/ (2 * width) < 128) pixels.fillRange(0, pw * ph, 0xFF000000);
    for (var y = 0; y < height; y++) {
      final row = (y + border) * pw + border;
      for (var x = 0; x < width; x++) {
        final v = lum[y * width + x];
        pixels[row + x] = 0xFF000000 | (v << 16) | (v << 8) | v;
      }
    }
    final source = RGBLuminanceSource(pw, ph, pixels);
    final hints = DecodeHints()
      ..put(DecodeHintType.tryHarder)
      // qr / qr_flutter içeriği her zaman UTF-8 bayt kipinde yazar.
      ..put(DecodeHintType.characterSet, 'UTF-8');
    // Dosyaya kaydedilmiş "saf" QR (yalnızca kod + kenarlık) için doğrudan
    // ızgara okuma daha güvenilir; fotoğraflar için bulucu desen algılayıcı.
    final pureHints = DecodeHints()
      ..put(DecodeHintType.pureBarcode)
      ..put(DecodeHintType.characterSet, 'UTF-8');
    for (final src in <LuminanceSource>[
      source,
      InvertedLuminanceSource(source)
    ]) {
      for (final h in [pureHints, hints]) {
        for (final bitmap in [
          BinaryBitmap(HybridBinarizer(src)),
          BinaryBitmap(GlobalHistogramBinarizer(src)),
        ]) {
          try {
            final result = QRCodeReader().decode(bitmap, hints: h);
            return DecodedCode(_qrText(result), 'qrCode');
          } catch (_) {
            // Bulunamadı / bozuk görsel: sonraki yöntemi dene.
          }
        }
      }
    }
    return null;
  }

  /// zxing2 bayt kipini UTF-8 olarak çözemiyor ("ğ" → "��").
  /// Metnin tamamı bayt segmentlerinden geliyorsa baytları UTF-8 olarak
  /// yeniden çöz; geçersiz UTF-8 ise zxing'in metnine dön.
  static String _qrText(Result result) {
    final segments = result.resultMetadata[ResultMetadataType.byteSegments];
    if (segments is! List<Int8List> || segments.isEmpty) return result.text;
    final bytes = <int>[
      for (final s in segments)
        ...Uint8List.view(s.buffer, s.offsetInBytes, s.length),
    ];
    if (bytes.length != result.text.length) return result.text;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return result.text;
    }
  }
}

/// Code128 ve EAN-13 için satır (ve 90° döndürülmüş görselde sütun) tarayıcı.
abstract final class LinearBarcodeScanner {
  static DecodedCode? scan(Uint8List lum, int width, int height) {
    // Önce yatay satırlar, sonra dikey sütunlar (dönük barkod).
    for (final horizontal in [true, false]) {
      final length = horizontal ? width : height;
      final lines = horizontal ? height : width;
      if (length < 30 || lines < 1) continue;
      const samples = 15;
      for (var s = 0; s < samples; s++) {
        // Ortadan dışa doğru: önce merkez, sonra yukarı/aşağı.
        final offset = ((s + 1) ~/ 2) * (s.isOdd ? 1 : -1);
        final pos = lines ~/ 2 + offset * lines ~/ (samples + 2);
        if (pos < 0 || pos >= lines) continue;
        final line = Uint8List(length);
        for (var i = 0; i < length; i++) {
          line[i] = horizontal ? lum[pos * width + i] : lum[i * width + pos];
        }
        final found = decodeLine(line);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Tek bir gri tonlamalı tarama çizgisini çözer (her iki yönde).
  static DecodedCode? decodeLine(Uint8List line) {
    var lo = 255, hi = 0;
    for (final v in line) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    if (hi - lo < 48) return null;
    final threshold = (lo + hi) ~/ 2;

    // Koşu uzunlukları; ilk koşu her zaman açık renk (sessiz bölge) olsun.
    final runs = <int>[];
    var dark = false;
    var len = 0;
    for (final v in line) {
      final d = v < threshold;
      if (d == dark) {
        len++;
      } else {
        runs.add(len);
        dark = d;
        len = 1;
      }
    }
    runs.add(len);
    if (dark) runs.add(0); // son koşu da açık olsun

    // runs[0] açık; tek indeksler koyu.
    final reversed = runs.reversed.toList();
    return _ean13(runs) ??
        _code128(runs) ??
        _ean13(reversed) ??
        _code128(reversed);
  }

  // --- ortak ------------------------------------------------------------

  static double _variance(
      List<int> counters, int start, List<int> pattern, double maxIndividual) {
    var total = 0;
    var patternLength = 0;
    for (var i = 0; i < pattern.length; i++) {
      total += counters[start + i];
      patternLength += pattern[i];
    }
    if (total < patternLength) return double.infinity;
    final unit = total / patternLength;
    final maxV = maxIndividual * unit;
    var sum = 0.0;
    for (var i = 0; i < pattern.length; i++) {
      final v = (counters[start + i] - pattern[i] * unit).abs();
      if (v > maxV) return double.infinity;
      sum += v;
    }
    return sum / total;
  }

  static ({int index, double variance})? _best(List<int> runs, int start,
      List<List<int>> patterns, double maxAvg, double maxInd) {
    var bestIndex = -1;
    var bestVar = maxAvg;
    for (var i = 0; i < patterns.length; i++) {
      final v = _variance(runs, start, patterns[i], maxInd);
      if (v < bestVar) {
        bestVar = v;
        bestIndex = i;
      }
    }
    return bestIndex < 0 ? null : (index: bestIndex, variance: bestVar);
  }

  static bool _quietZone(List<int> runs, int darkStart, double module) =>
      runs[darkStart - 1] >= module * 5 || darkStart - 1 == 0 && runs[0] > 0;

  // --- EAN-13 -----------------------------------------------------------

  static const _eanL = [
    [3, 2, 1, 1],
    [2, 2, 2, 1],
    [2, 1, 2, 2],
    [1, 4, 1, 1],
    [1, 1, 3, 2],
    [1, 2, 3, 1],
    [1, 1, 1, 4],
    [1, 3, 1, 2],
    [1, 2, 1, 3],
    [3, 1, 1, 2],
  ];
  static final _eanG = [for (final p in _eanL) p.reversed.toList()];
  static final _eanLG = [..._eanL, ..._eanG];
  // İlk hane → sol 6 hanenin L/G düzeni (G = 1).
  static const _eanFirst = [
    0x00,
    0x0B,
    0x0D,
    0x0E,
    0x13,
    0x19,
    0x1C,
    0x15,
    0x16,
    0x1A,
  ];

  static DecodedCode? _ean13(List<int> runs) {
    // 3 + 24 + 5 + 24 + 3 = 59 koşu.
    for (var s = 1; s + 59 <= runs.length; s += 2) {
      if (_variance(runs, s, const [1, 1, 1], 0.7) > 0.48) continue;
      final module = (runs[s] + runs[s + 1] + runs[s + 2]) / 3;
      if (!_quietZone(runs, s, module)) continue;
      final digits = StringBuffer();
      var parity = 0;
      var p = s + 3;
      var ok = true;
      for (var i = 0; i < 6 && ok; i++, p += 4) {
        final m = _best(runs, p, _eanLG, 0.48, 0.7);
        if (m == null) {
          ok = false;
        } else {
          digits.write(m.index % 10);
          if (m.index >= 10) parity |= 1 << (5 - i);
        }
      }
      if (!ok) continue;
      if (_variance(runs, p, const [1, 1, 1, 1, 1], 0.7) > 0.48) continue;
      p += 5;
      for (var i = 0; i < 6 && ok; i++, p += 4) {
        final m = _best(runs, p, _eanL, 0.48, 0.7);
        if (m == null) {
          ok = false;
        } else {
          digits.write(m.index);
        }
      }
      if (!ok) continue;
      if (_variance(runs, p, const [1, 1, 1], 0.7) > 0.48) continue;
      final first = _eanFirst.indexOf(parity);
      if (first < 0) continue;
      final code = '$first$digits';
      if (!_eanChecksumOk(code)) continue;
      return DecodedCode(code, 'ean13');
    }
    return null;
  }

  static bool _eanChecksumOk(String code) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final n = code.codeUnitAt(i) - 48;
      sum += i.isEven ? n : n * 3;
    }
    return (10 - sum % 10) % 10 == code.codeUnitAt(12) - 48;
  }

  // --- Code128 ----------------------------------------------------------

  static List<List<int>> _parse(String s) => [
        for (final w in s.split(' '))
          [for (final c in w.split('')) int.parse(c)]
      ];

  /// Değer 0..105 için çubuk/boşluk genişlikleri (ISO/IEC 15417 tablosu).
  static final _c128 = _parse(
    '212222 222122 222221 121223 121322 131222 122213 122312 132212 221213 '
    '221312 231212 112232 122132 122231 113222 123122 123221 223211 221132 '
    '221231 213212 223112 312131 311222 321122 321221 312212 322112 322211 '
    '212123 212321 232121 111323 131123 131321 112313 132113 132311 211313 '
    '231113 231311 112133 112331 132131 113123 113321 133121 313121 211331 '
    '231131 213113 213311 213131 311123 311321 331121 312113 312311 332111 '
    '314111 221411 431111 111224 111422 121124 121421 141122 141221 112214 '
    '112412 122114 122411 142112 142211 241211 221114 413111 241112 134111 '
    '111242 121142 121241 114212 124112 124211 411212 421112 421211 212141 '
    '214121 412121 111143 111341 131141 114113 114311 411113 411311 113141 '
    '114131 311141 411131 211412 211214 211232',
  );
  static final _c128Data = _c128.sublist(0, 103);
  static final _c128Start = _c128.sublist(103);
  static const _c128Stop = [2, 3, 3, 1, 1, 1, 2];

  static DecodedCode? _code128(List<int> runs) {
    for (var s = 1; s + 6 + 6 + 7 <= runs.length; s += 2) {
      final start = _best(runs, s, _c128Start, 0.25, 0.7);
      if (start == null) continue;
      final module =
          [for (var i = 0; i < 6; i++) runs[s + i]].reduce((a, b) => a + b) /
              11;
      if (!_quietZone(runs, s, module)) continue;
      final values = <int>[103 + start.index];
      var p = s + 6;
      var stopped = false;
      while (p + 7 <= runs.length) {
        if (_variance(runs, p, _c128Stop, 0.7) < 0.25) {
          stopped = true;
          break;
        }
        final m = _best(runs, p, _c128Data, 0.25, 0.7);
        if (m == null) break;
        values.add(m.index);
        p += 6;
      }
      if (!stopped || values.length < 3) continue;
      final text = _code128Text(values);
      if (text != null) return DecodedCode(text, 'code128');
    }
    return null;
  }

  /// Sağlama değerini doğrular ve A/B/C kod kümelerini metne çevirir.
  static String? _code128Text(List<int> values) {
    final check = values.last;
    var sum = values.first;
    for (var i = 1; i < values.length - 1; i++) {
      sum += values[i] * i;
    }
    if (sum % 103 != check) return null;

    var set = switch (values.first) { 103 => 'A', 104 => 'B', _ => 'C' };
    final out = StringBuffer();
    String? shiftTo;
    for (var i = 1; i < values.length - 1; i++) {
      final v = values[i];
      final cur = shiftTo ?? set;
      shiftTo = null;
      if (cur == 'C') {
        if (v < 100) {
          out.write(v.toString().padLeft(2, '0'));
        } else if (v == 100) {
          set = 'B';
        } else if (v == 101) {
          set = 'A';
        }
        continue;
      }
      if (v < 64) {
        out.writeCharCode(v + 32);
      } else if (v < 96) {
        out.writeCharCode(cur == 'A' ? v - 64 : v + 32);
      } else if (v == 98) {
        shiftTo = cur == 'A' ? 'B' : 'A';
      } else if (v == 99) {
        set = 'C';
      } else if (v == 100 && cur == 'A' || v == 101 && cur == 'B') {
        // FNC4 (genişletilmiş ASCII) desteklenmez; yok say.
      } else if (v == 100) {
        set = 'B';
      } else if (v == 101) {
        set = 'A';
      }
      // 96/97 (FNC3/FNC2) ve 102 (FNC1) metne yansımaz.
    }
    return out.toString();
  }
}
