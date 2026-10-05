import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/batch_export.dart';

void main() {
  test('parseLines handles csv first column', () {
    const raw = 'url1,extra\nurl2\n\nurl3,ignored';
    expect(BatchExport.parseLines(raw), ['url1', 'url2', 'url3']);
  });

  test('parseLines caps at 100', () {
    final lines = List.generate(150, (i) => 'https://x.com/$i').join('\n');
    expect(BatchExport.parseLines(lines).length, 100);
  });
}
