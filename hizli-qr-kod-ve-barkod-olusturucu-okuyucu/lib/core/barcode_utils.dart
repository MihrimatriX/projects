import 'package:barcode/barcode.dart';

enum AppBarcodeType { code128, ean13 }

abstract final class BarcodeUtils {
  static Barcode barcodeFor(AppBarcodeType type) => switch (type) {
        AppBarcodeType.code128 => Barcode.code128(),
        AppBarcodeType.ean13 => Barcode.ean13(),
      };

  static String? validate(AppBarcodeType type, String raw) {
    final data = raw.trim();
    if (data.isEmpty) return 'Veri boş olamaz';

    return switch (type) {
      AppBarcodeType.code128 => data.length > 80
          ? 'Code128 en fazla ~80 karakter destekler'
          // Code128 yalnızca ASCII kodlar; "ş", "ğ" gibi karakterler çizimde hata verir.
          : (Barcode.code128().isValid(data) ? null : 'Code128 yalnızca ASCII karakter destekler'),
      AppBarcodeType.ean13 => _validateEan13(data),
    };
  }

  static String? _validateEan13(String data) {
    final digits = data.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 12 && digits.length != 13) {
      return 'EAN-13 için 12 veya 13 rakam girin';
    }
    final code = digits.length == 13 ? digits : '$digits${_eanCheckDigit(digits)}';
    if (!Barcode.ean13().isValid(code)) {
      return 'Geçersiz EAN-13 kontrol basamağı';
    }
    return null;
  }

  static String normalize(AppBarcodeType type, String raw) {
    final data = raw.trim();
    if (type == AppBarcodeType.ean13) {
      final digits = data.replaceAll(RegExp(r'\D'), '');
      if (digits.length == 12) return '$digits${_eanCheckDigit(digits)}';
      return digits;
    }
    return data;
  }

  static int _eanCheckDigit(String twelve) {
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      final n = int.parse(twelve[i]);
      sum += i.isEven ? n : n * 3;
    }
    return (10 - (sum % 10)) % 10;
  }
}
