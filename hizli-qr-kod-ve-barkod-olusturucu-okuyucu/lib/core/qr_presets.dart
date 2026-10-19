/// WiFi, vCard ve URL için QR içerik üreticileri.
abstract final class QrPresets {
  static String wifi({
    required String ssid,
    required String password,
    String encryption = 'WPA',
  }) {
    final enc = switch (encryption) {
      'WEP' => 'WEP',
      'nopass' => 'nopass',
      _ => 'WPA',
    };
    return 'WIFI:T:$enc;S:${_escape(ssid)};P:${_escape(password)};;';
  }

  static String vcard({
    required String name,
    String? phone,
    String? email,
  }) {
    final buf = StringBuffer('BEGIN:VCARD\nVERSION:3.0\nFN:$name\n');
    if (phone != null && phone.trim().isNotEmpty) {
      buf.writeln('TEL:$phone');
    }
    if (email != null && email.trim().isNotEmpty) {
      buf.writeln('EMAIL:$email');
    }
    buf.write('END:VCARD');
    return buf.toString();
  }

  static String url(String href) {
    final t = href.trim();
    if (t.isEmpty) return 'https://';
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://$t';
  }

  /// `WIFI:T:WPA;S:ag;P:sifre;;` → alanlar. Kaçışlı `\;` `\,` `\:` `\\` çözülür.
  /// Okunan bir Wi-Fi kodu "QR oluştur" ile forma yüklenirken kullanılır.
  static ({String ssid, String password, String encryption})? parseWifi(String raw) {
    if (!raw.startsWith('WIFI:')) return null;
    final fields = <String, String>{};
    final body = raw.substring(5);
    var key = StringBuffer();
    var value = StringBuffer();
    var inValue = false;
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (c == r'\' && i + 1 < body.length) {
        (inValue ? value : key).write(body[++i]);
      } else if (!inValue && c == ':') {
        inValue = true;
      } else if (c == ';') {
        if (key.isNotEmpty) fields[key.toString().toUpperCase()] = value.toString();
        key = StringBuffer();
        value = StringBuffer();
        inValue = false;
      } else {
        (inValue ? value : key).write(c);
      }
    }
    if (key.isNotEmpty) fields[key.toString().toUpperCase()] = value.toString();
    final ssid = fields['S'];
    if (ssid == null) return null;
    final t = (fields['T'] ?? '').toUpperCase();
    final enc = t == 'WEP'
        ? 'WEP'
        : (t.isEmpty || t == 'NOPASS')
            ? ((fields['P'] ?? '').isEmpty ? 'nopass' : 'WPA')
            : 'WPA';
    return (ssid: ssid, password: fields['P'] ?? '', encryption: enc);
  }

  /// vCard'dan ad / telefon / e-posta (FN yoksa N alanı).
  static ({String name, String phone, String email})? parseVcard(String raw) {
    if (!raw.trimLeft().toUpperCase().startsWith('BEGIN:VCARD')) return null;
    String? fn, n, tel, email;
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      // "TEL;TYPE=CELL:..." gibi parametreleri at.
      final name = line.substring(0, colon).split(';').first.trim().toUpperCase();
      final value = line.substring(colon + 1).trim();
      switch (name) {
        case 'FN':
          fn ??= value;
        case 'N':
          n ??= value.split(';').where((p) => p.isNotEmpty).toList().reversed.join(' ');
        case 'TEL':
          tel ??= value;
        case 'EMAIL':
          email ??= value;
      }
    }
    return (name: fn ?? n ?? '', phone: tel ?? '', email: email ?? '');
  }

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll(';', r'\;').replaceAll(',', r'\,');
}
