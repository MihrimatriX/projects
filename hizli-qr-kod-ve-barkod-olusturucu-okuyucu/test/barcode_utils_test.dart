import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/barcode_utils.dart';

void main() {
  test('EAN-13 adds check digit for 12 digits', () {
    final normalized = BarcodeUtils.normalize(AppBarcodeType.ean13, '400638133393');
    expect(normalized.length, 13);
    expect(BarcodeUtils.validate(AppBarcodeType.ean13, normalized), isNull);
  });

  test('Code128 rejects non-ASCII', () {
    expect(BarcodeUtils.validate(AppBarcodeType.code128, 'çay'), isNotNull);
    expect(BarcodeUtils.validate(AppBarcodeType.code128, 'ABC-123'), isNull);
  });

  test('Code128 rejects empty', () {
    expect(BarcodeUtils.validate(AppBarcodeType.code128, ''), isNotNull);
  });
}
