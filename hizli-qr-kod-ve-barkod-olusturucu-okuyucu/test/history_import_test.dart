import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/history_import.dart';

void main() {
  test('parseJson reads created and scanned lists', () {
    const raw = '''
    {"created":["https://a.com"],"scanned":["text1","text2"]}
    ''';
    final result = HistoryImport.parseJson(raw);
    expect(result, isNotNull);
    expect(result!.created, ['https://a.com']);
    expect(result.scanned, ['text1', 'text2']);
  });

  test('parseJson returns null for invalid', () {
    expect(HistoryImport.parseJson('not json'), isNull);
  });
}
