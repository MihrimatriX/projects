import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_qr_kod_ve_barkod_olusturucu_okuyucu/core/qr_presets.dart';

void main() {
  test('wifi preset escapes special chars', () {
    final s = QrPresets.wifi(ssid: 'Cafe;1', password: 'a,b', encryption: 'WPA');
    expect(s, contains(r'S:Cafe\;1'));
    expect(s, contains(r'P:a\,b'));
    expect(s, startsWith('WIFI:T:WPA;'));
  });

  test('vcard preset includes fields', () {
    final s = QrPresets.vcard(name: 'Ali Veli', phone: '555', email: 'a@b.com');
    expect(s, contains('FN:Ali Veli'));
    expect(s, contains('TEL:555'));
    expect(s, contains('EMAIL:a@b.com'));
    expect(s, endsWith('END:VCARD'));
  });

  test('url preset adds https', () {
    expect(QrPresets.url('example.com'), 'https://example.com');
    expect(QrPresets.url('https://x.com'), 'https://x.com');
  });

  test('Wi-Fi içeriği alanlara geri ayrıştırılır (kaçışlar dahil)', () {
    for (final (ssid, pass, enc) in [
      ('Cafe;1', r'a,b\c:d', 'WPA'),
      ('Ev Ağı', 'şifre', 'WEP'),
      ('Misafir', '', 'nopass'),
    ]) {
      final parsed = QrPresets.parseWifi(QrPresets.wifi(ssid: ssid, password: pass, encryption: enc));
      expect(parsed?.ssid, ssid);
      expect(parsed?.password, pass);
      expect(parsed?.encryption, enc);
    }
    expect(QrPresets.parseWifi('WIFI:S:Ag;P:x;;')?.encryption, 'WPA');
    expect(QrPresets.parseWifi('merhaba'), isNull);
  });

  test('vCard alanları geri ayrıştırılır', () {
    final v = QrPresets.parseVcard(
      QrPresets.vcard(name: 'Ayşe Yılmaz', phone: '+90 555', email: 'a@b.com'),
    );
    expect(v?.name, 'Ayşe Yılmaz');
    expect(v?.phone, '+90 555');
    expect(v?.email, 'a@b.com');
    final n = QrPresets.parseVcard('BEGIN:VCARD\r\nN:Veli;Ali;;;\r\nTEL;TYPE=CELL:123\r\nEND:VCARD');
    expect(n?.name, 'Ali Veli');
    expect(n?.phone, '123');
  });
}