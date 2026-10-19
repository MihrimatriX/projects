import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/history_display.dart';

void main() {
  test('masks wifi password', () {
    const raw = 'WIFI:T:WPA;S:Home;P:secret123;;';
    final masked = HistoryDisplay.mask(raw, maskWifiPasswords: true);
    expect(masked, contains('P:••••••'));
    expect(masked, isNot(contains('secret123')));
  });

  test('leaves non-wifi unchanged', () {
    expect(HistoryDisplay.mask('https://a.com', maskWifiPasswords: true), 'https://a.com');
  });
}
