abstract final class UrlUtils {
  static bool looksLikeUrl(String text) {
    final t = text.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return true;
    final noScheme = RegExp(r'^[a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,}');
    return noScheme.hasMatch(t);
  }

  static String normalizeUrl(String text) {
    final t = text.trim();
    if (t.startsWith('http://') || t.startsWith('https://')) return t;
    return 'https://$t';
  }
}
