/// Geçmiş listelerinde hassas içerik gösterimi.
abstract final class HistoryDisplay {
  static final _wifiPassword = RegExp(r'(P:)([^;]*)(;)', caseSensitive: false);

  static bool isWifiPayload(String text) => text.trim().startsWith('WIFI:');

  static String mask(String text, {required bool maskWifiPasswords}) {
    if (!maskWifiPasswords || !isWifiPayload(text)) return text;
    return text.replaceAllMapped(_wifiPassword, (m) => '${m[1]}••••••${m[3]}');
  }
}
