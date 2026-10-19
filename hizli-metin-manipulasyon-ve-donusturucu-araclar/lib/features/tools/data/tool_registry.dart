import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

enum ToolCategory {
  encode('Encode / Decode', Icons.code_outlined),
  hash('Hash', Icons.fingerprint_outlined),
  format('Format', Icons.data_object_outlined),
  generate('Generate', Icons.auto_awesome_outlined),
  convert('Convert', Icons.swap_horiz_outlined);

  const ToolCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// [output] bir dönüşüm hatası mı? [tool] verilirse yalnızca hata
/// üretebilen araçlar için kontrol edilir; böylece "Geçersiz ..." ile başlayan
/// sıradan bir metni kırpmak/çevirmek hata sayılmaz.
bool isTransformError(String output, [TextTool? tool]) {
  if (tool != null && !tool.canFail) return false;
  return output.startsWith('Geçersiz') || output.startsWith('JWT decode hatası');
}

final _privateKeyPattern =
    RegExp(r'-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----', caseSensitive: false);
final _jwtPattern = RegExp(r'^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$');

bool looksSensitive(String input) {
  final t = input.trim();
  if (t.isEmpty) return false;
  if (_privateKeyPattern.hasMatch(t)) return true;
  return _jwtPattern.hasMatch(t);
}

class TextTool {
  const TextTool({
    required this.id,
    required this.name,
    required this.category,
    required this.transform,
    this.description = '',
    this.canFail = false,
  });

  final String id;
  final String name;
  final ToolCategory category;
  final String description;

  /// Geçersiz girdide 'Geçersiz ...' metni dönebilir.
  final bool canFail;

  /// Saf, üst düzey fonksiyon olmalıdır: büyük girdilerde ayrı bir isolate'e
  /// gönderilir.
  final String Function(String input) transform;
}

// Her araç saf bir String -> String fonksiyonudur; ekran seçili aracın
// transform'unu girdiye uygular. Hata durumları istisna yerine
// 'Geçersiz ...' metni döner (bkz. isTransformError).
final allTextTools = <TextTool>[
  const TextTool(
    id: 'base64-encode',
    name: 'Base64 encode',
    category: ToolCategory.encode,
    transform: encodeBase64,
  ),
  const TextTool(
    id: 'base64-decode',
    name: 'Base64 decode',
    category: ToolCategory.encode,
    description: 'Standart ve URL-safe, boşluk/satır sonu toleranslı',
    transform: decodeBase64,
    canFail: true,
  ),
  const TextTool(
    id: 'url-encode',
    name: 'URL encode',
    category: ToolCategory.encode,
    transform: urlEncode,
  ),
  const TextTool(
    id: 'url-decode',
    name: 'URL decode',
    category: ToolCategory.encode,
    transform: urlDecode,
    canFail: true,
  ),
  const TextTool(
    id: 'html-encode',
    name: 'HTML entities encode',
    category: ToolCategory.encode,
    transform: htmlEncode,
  ),
  const TextTool(
    id: 'html-decode',
    name: 'HTML entities decode',
    category: ToolCategory.encode,
    description: 'Adlı (&amp;nbsp;) ve sayısal (&amp;#351;, &amp;#x15F;) varlıklar',
    transform: htmlDecode,
  ),
  const TextTool(
    id: 'jwt-decode',
    name: 'JWT decode (payload)',
    category: ToolCategory.encode,
    description: 'JWT payload JSON (base64url)',
    transform: decodeJwtPayload,
    canFail: true,
  ),
  const TextTool(
    id: 'jwt-decode-header',
    name: 'JWT decode (header)',
    category: ToolCategory.encode,
    description: 'JWT header JSON',
    transform: decodeJwtHeader,
    canFail: true,
  ),
  const TextTool(
    id: 'md5',
    name: 'MD5',
    category: ToolCategory.hash,
    transform: hashMd5,
  ),
  const TextTool(
    id: 'sha256',
    name: 'SHA-256',
    category: ToolCategory.hash,
    transform: hashSha256,
  ),
  const TextTool(
    id: 'json-pretty',
    name: 'JSON pretty',
    category: ToolCategory.format,
    transform: jsonPretty,
    canFail: true,
  ),
  const TextTool(
    id: 'json-minify',
    name: 'JSON minify',
    category: ToolCategory.format,
    transform: jsonMinify,
    canFail: true,
  ),
  const TextTool(
    id: 'trim',
    name: 'Trim whitespace',
    category: ToolCategory.format,
    transform: trimWhitespace,
  ),
  const TextTool(
    id: 'line-sort',
    name: 'Sort lines (A-Z)',
    category: ToolCategory.format,
    description: 'Türk alfabesi sırası, büyük/küçük harf duyarsız',
    transform: sortLines,
  ),
  const TextTool(
    id: 'line-dedupe',
    name: 'Tekrarlanan satırları sil',
    category: ToolCategory.format,
    description: 'İlk geçişi korur, sırayı bozmaz',
    transform: dedupeLines,
  ),
  const TextTool(
    id: 'uuid-v4',
    name: 'UUID v4',
    category: ToolCategory.generate,
    transform: generateUuidV4Tool,
  ),
  const TextTool(
    id: 'random-string',
    name: 'Random string (16)',
    category: ToolCategory.generate,
    transform: generateRandomString16,
  ),
  const TextTool(
    id: 'camel-case',
    name: 'camelCase',
    category: ToolCategory.convert,
    transform: toCamelCase,
  ),
  const TextTool(
    id: 'snake-case',
    name: 'snake_case',
    category: ToolCategory.convert,
    transform: toSnakeCase,
  ),
  const TextTool(
    id: 'kebab-case',
    name: 'kebab-case',
    category: ToolCategory.convert,
    transform: toKebabCase,
  ),
  const TextTool(
    id: 'slug',
    name: 'Slug (URL dostu)',
    category: ToolCategory.convert,
    description: 'Türkçe karakterleri sadeleştirir: "Çalışma Şekli" → calisma-sekli',
    transform: toSlug,
  ),
  const TextTool(
    id: 'timestamp-iso',
    name: 'Unix → ISO',
    category: ToolCategory.convert,
    transform: timestampToIso,
    canFail: true,
  ),
  const TextTool(
    id: 'upper',
    name: 'UPPERCASE',
    category: ToolCategory.convert,
    description: 'Dilden bağımsız (i → I)',
    transform: toUpperCase,
  ),
  const TextTool(
    id: 'lower',
    name: 'lowercase',
    category: ToolCategory.convert,
    description: 'Dilden bağımsız (I → i)',
    transform: toLowerCase,
  ),
  const TextTool(
    id: 'upper-tr',
    name: 'BÜYÜK HARF (Türkçe)',
    category: ToolCategory.convert,
    description: 'i → İ, ı → I',
    transform: toUpperTr,
  ),
  const TextTool(
    id: 'lower-tr',
    name: 'küçük harf (Türkçe)',
    category: ToolCategory.convert,
    description: 'I → ı, İ → i',
    transform: toLowerTr,
  ),
  const TextTool(
    id: 'title-tr',
    name: 'Başlık Düzeni (Türkçe)',
    category: ToolCategory.convert,
    description: 'Her kelimenin ilk harfi büyük: "istanbul\'da ılık" → "İstanbul\'da Ilık"',
    transform: toTitleTr,
  ),
  const TextTool(
    id: 'word-count',
    name: 'Word / char count',
    category: ToolCategory.format,
    transform: wordCount,
  ),
  const TextTool(
    id: 'reverse',
    name: 'Reverse text',
    category: ToolCategory.convert,
    transform: reverseText,
  ),
];

TextTool? findToolById(String id) {
  for (final t in allTextTools) {
    if (t.id == id) return t;
  }
  return null;
}

/// Arama için katlama: Türkçe küçük harf + aksan/şapka sadeleştirme.
/// "buyuk", "BÜYÜK" ve "Büyük" aynı sonucu verir.
String foldForSearch(String s) => _asciiFold(toLowerTr(s));

List<TextTool> filterTools(String query) {
  if (query.trim().isEmpty) return allTextTools;
  final q = foldForSearch(query.trim());
  return allTextTools.where((t) {
    return foldForSearch(t.name).contains(q) ||
        t.id.contains(q) ||
        foldForSearch(t.category.label).contains(q) ||
        foldForSearch(t.description).contains(q);
  }).toList();
}

String trimWhitespace(String s) => s.trim();

// --- Büyük/küçük harf ---------------------------------------------------------
// Dart'ın toUpperCase/toLowerCase'i dilden bağımsızdır: 'i' → 'I' ve
// 'İ' → 'i̇' (i + U+0307 birleşen nokta) üretir. Türkçe için noktalı/noktasız
// i çiftleri elle eşlenir.

/// Dilden bağımsız büyük harf.
String toUpperCase(String s) => s.toUpperCase();

/// Dilden bağımsız küçük harf; 'İ' tek başına 'i' olur (artık nokta bırakmaz).
String toLowerCase(String s) => s.replaceAll('İ', 'i').toLowerCase();

/// Türkçe büyük harf: i → İ, ı → I.
String toUpperTr(String s) => s.replaceAll('i', 'İ').toUpperCase();

/// Türkçe küçük harf: I → ı, İ (ve ayrışık I + U+0307) → i.
String toLowerTr(String s) => s
    .replaceAll('İ', 'i')
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase();

// --- Karakter sınıfı (önbellekli) -------------------------------------------------
// Büyük girdilerde karakter başına RegExp çalıştırmamak için sınıf bir kez
// hesaplanır. 0: diğer, 1: büyük harf, 2: diğer harf, 3: rakam, 4: birleşen işaret.
const _clsOther = 0, _clsUpper = 1, _clsLetter = 2, _clsDigit = 3, _clsMark = 4;
final _reUpper = RegExp(r'[\p{Lu}\p{Lt}]', unicode: true);
final _reLetter = RegExp(r'\p{L}', unicode: true);
final _reDigit = RegExp(r'\p{N}', unicode: true);
final _reMark = RegExp(r'\p{M}', unicode: true);
final _classCache = <int, int>{};

int _charClass(int r) {
  if (r < 0x80) {
    if (r >= 0x41 && r <= 0x5A) return _clsUpper;
    if (r >= 0x61 && r <= 0x7A) return _clsLetter;
    if (r >= 0x30 && r <= 0x39) return _clsDigit;
    return _clsOther;
  }
  return _classCache[r] ??= _classify(r);
}

int _classify(int r) {
  final ch = String.fromCharCode(r);
  if (_reUpper.hasMatch(ch)) return _clsUpper;
  if (_reLetter.hasMatch(ch)) return _clsLetter;
  if (_reDigit.hasMatch(ch)) return _clsDigit;
  if (_reMark.hasMatch(ch)) return _clsMark;
  return _clsOther;
}

bool _isApostrophe(int r) => r == 0x27 || r == 0x2019;

/// Türkçe başlık düzeni: her kelimenin ilk harfi büyük, kalanı küçük.
/// Kesme işaretli ekler ("İstanbul'da") kelimenin parçası sayılır.
String toTitleTr(String s) {
  final b = StringBuffer();
  var inWord = false;
  for (final r in toLowerTr(s).runes) {
    final cls = _charClass(r);
    if (cls == _clsOther && !(inWord && _isApostrophe(r))) {
      inWord = false;
      b.writeCharCode(r);
    } else if (!inWord && cls != _clsMark) {
      inWord = true;
      b.write(toUpperTr(String.fromCharCode(r)));
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

// runes yerine grafem kümeleri: bayraklar, ZWJ emoji aileleri ve birleşen
// aksanlar (e + U+0301) ters çevirmede bozulmaz.
String reverseText(String s) => s.characters.toList().reversed.join();
String generateUuidV4Tool(String _) => generateUuidV4();
String generateRandomString16(String _) => generateRandomString(16);

// --- Encode / decode ------------------------------------------------------------

String encodeBase64(String input) =>
    input.isEmpty ? '' : base64Encode(utf8.encode(input));

final _whitespace = RegExp(r'\s+');

String decodeBase64(String input) {
  var s = input.replaceAll(_whitespace, '');
  if (s.isEmpty) return '';
  // URL-safe alfabe ve eksik dolgu (=) kabul edilir.
  s = s.replaceAll('-', '+').replaceAll('_', '/');
  final rem = s.length % 4;
  if (rem == 1) return 'Geçersiz Base64: uzunluk hatalı';
  if (rem != 0) s += '=' * (4 - rem);
  final List<int> bytes;
  try {
    bytes = base64Decode(s);
  } on FormatException {
    return 'Geçersiz Base64: izin verilmeyen karakter veya dolgu';
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return 'Geçersiz Base64: çözülen veri UTF-8 metin değil (${bytes.length} bayt ikili veri)';
  }
}

String urlEncode(String input) => Uri.encodeComponent(input);

String urlDecode(String input) {
  if (input.isEmpty) return '';
  try {
    return Uri.decodeComponent(input);
  } catch (_) {
    return 'Geçersiz URL: hatalı % kaçışı veya UTF-8 dizisi';
  }
}

String htmlEncode(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'laquo': '«',
  'raquo': '»',
  'euro': '€',
  'deg': '°',
  'times': '×',
};

final _entityPattern = RegExp(r'&(#[xX][0-9a-fA-F]{1,6}|#[0-9]{1,7}|[a-zA-Z]{2,8});');

/// Tek geçişte çözer; "&amp;lt;" → "&lt;" (çift çözme yok). Bilinmeyen veya
/// geçersiz varlıklar olduğu gibi bırakılır.
String htmlDecode(String input) {
  return input.replaceAllMapped(_entityPattern, (m) {
    final body = m[1]!;
    if (body.startsWith('#')) {
      final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
      final code = int.tryParse(body.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
      if (code == null || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) {
        return m[0]!;
      }
      return String.fromCharCode(code);
    }
    return _namedEntities[body] ?? m[0]!;
  });
}

String hashMd5(String input) {
  if (input.isEmpty) return '';
  return md5.convert(utf8.encode(input)).toString();
}

String hashSha256(String input) {
  if (input.isEmpty) return '';
  return sha256.convert(utf8.encode(input)).toString();
}

String jsonPretty(String input) {
  if (input.trim().isEmpty) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(input));
  } on FormatException catch (e) {
    return 'Geçersiz JSON: ${e.message}${e.offset != null ? ' (konum ${e.offset})' : ''}';
  }
}

String jsonMinify(String input) {
  if (input.trim().isEmpty) return '';
  try {
    return jsonEncode(jsonDecode(input));
  } on FormatException catch (e) {
    return 'Geçersiz JSON: ${e.message}${e.offset != null ? ' (konum ${e.offset})' : ''}';
  }
}

// --- Satır araçları -------------------------------------------------------------

/// Satırları ayırır; Windows (\r\n) satır sonlarını ve sondaki boş satırı korur.
(List<String> lines, String eol, bool trailing) _splitLines(String input) {
  final eol = input.contains('\r\n') ? '\r\n' : '\n';
  var body = input;
  final trailing = body.endsWith(eol);
  if (trailing) body = body.substring(0, body.length - eol.length);
  return (body.split(eol), eol, trailing);
}

String _joinLines(List<String> lines, String eol, bool trailing) =>
    lines.join(eol) + (trailing ? eol : '');

const _trAlphabet = 'abcçdefgğhıijklmnoöpqrsştuüvwxyz';

final _rankCache = <int, int>{};

/// Sıralama anahtarı: harf olmayanlar (boşluk, rakam, noktalama) kod
/// sırasıyla önce; sonra Türk alfabesindeki harfler; sonra diğer harfler.
// Latin-1 + Latin Genişletilmiş-A (Türkçe harfler dahil) için düz tablo.
final _latinRanks = List<int>.generate(0x180, _computeRank, growable: false);

int _trRank(int rune) =>
    rune < 0x180 ? _latinRanks[rune] : (_rankCache[rune] ??= _computeRank(rune));

int _computeRank(int rune) {
  final ch = String.fromCharCode(rune);
  final lower = toLowerTr(ch);
  final idx = lower.length == 1 ? _trAlphabet.indexOf(lower) : -1;
  if (idx >= 0) return 0x200000 + idx;
  final cls = _charClass(rune);
  if (cls == _clsUpper || cls == _clsLetter) return 0x300000 + lower.runes.first;
  return rune;
}

/// Türk alfabesine göre (a b c ç d … ı i … ş … ü …), büyük/küçük harf duyarsız
/// karşılaştırma. Eşitlikte büyük harf önce gelir; sonuç kararlıdır.
int compareTr(String a, String b) => _compareKeyed(_keyed(a), _keyed(b));

(List<int>, String) _keyed(String s) => (s.runes.map(_trRank).toList(), s);

int _compareKeyed((List<int>, String) a, (List<int>, String) b) {
  final ra = a.$1;
  final rb = b.$1;
  final n = min(ra.length, rb.length);
  for (var i = 0; i < n; i++) {
    final c = ra[i].compareTo(rb[i]);
    if (c != 0) return c;
  }
  final c = ra.length.compareTo(rb.length);
  return c != 0 ? c : a.$2.compareTo(b.$2);
}

String sortLines(String input) {
  if (input.isEmpty) return '';
  final (lines, eol, trailing) = _splitLines(input);
  // Anahtarlar bir kez hesaplanır; büyük girdide karşılaştırma başına
  // ayırma yapılmaz.
  final keyed = lines.map(_keyed).toList()..sort(_compareKeyed);
  return _joinLines(keyed.map((k) => k.$2).toList(), eol, trailing);
}

String dedupeLines(String input) {
  if (input.isEmpty) return '';
  final (lines, eol, trailing) = _splitLines(input);
  final seen = <String>{};
  return _joinLines(lines.where(seen.add).toList(), eol, trailing);
}

// --- Üreticiler -----------------------------------------------------------------

String generateUuidV4() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int i) => bytes[i].toRadixString(16).padLeft(2, '0');
  return '${hex(0)}${hex(1)}${hex(2)}${hex(3)}-'
      '${hex(4)}${hex(5)}-'
      '${hex(6)}${hex(7)}-'
      '${hex(8)}${hex(9)}-'
      '${hex(10)}${hex(11)}${hex(12)}${hex(13)}${hex(14)}${hex(15)}';
}

String generateRandomString(int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final r = Random.secure();
  return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
}

// --- Kod biçimleri (camel/snake/kebab/slug) -----------------------------------------

/// Harf/rakam dışı her şeyde ve camelCase tümseklerinde böler
/// ("parseHTTPResponse2Json" → parse HTTP Response2 Json). Türkçe ve diğer
/// Unicode harfler korunur (eskiden yalnızca a-z kalıyordu: "Çalışma" → "al ma").
/// Tek geçişte çalışır; megabaytlık girdide de hızlıdır.
List<String> _normalizeWords(String s) {
  final runes = s.runes.toList();
  final words = <String>[];
  var start = -1;
  void flush(int end) {
    if (start >= 0 && end > start) words.add(String.fromCharCodes(runes, start, end));
    start = -1;
  }

  for (var i = 0; i < runes.length; i++) {
    final cls = _charClass(runes[i]);
    if (cls == _clsOther) {
      flush(i);
      continue;
    }
    if (start < 0) {
      start = i;
      continue;
    }
    if (cls != _clsUpper) continue;
    final prev = _charClass(runes[i - 1]);
    final nextLower = i + 1 < runes.length && _charClass(runes[i + 1]) == _clsLetter;
    if (prev == _clsLetter || prev == _clsDigit || (prev == _clsUpper && nextLower)) {
      flush(i);
      start = i;
    }
  }
  flush(runes.length);
  return words;
}

String _capitalize(String w) {
  final first = String.fromCharCode(w.runes.first);
  return first.toUpperCase() + toLowerCase(w.substring(first.length));
}

String toCamelCase(String input) {
  final words = _normalizeWords(input);
  if (words.isEmpty) return '';
  return toLowerCase(words.first) + words.skip(1).map(_capitalize).join();
}

String toSnakeCase(String input) {
  return _normalizeWords(input).map(toLowerCase).join('_');
}

String toKebabCase(String input) {
  return _normalizeWords(input).map(toLowerCase).join('-');
}

const _foldMap = {
  'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
  'â': 'a', 'î': 'i', 'û': 'u', 'à': 'a', 'á': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o', 'ù': 'u', 'ú': 'u',
  'ñ': 'n', 'ß': 'ss', 'æ': 'ae', 'œ': 'oe', 'ý': 'y', 'ÿ': 'y',
};

final _foldRunes = {for (final e in _foldMap.entries) e.key.runes.first: e.value};

String _asciiFold(String lower) {
  final b = StringBuffer();
  for (final r in lower.runes) {
    if (r < 0x80) {
      b.writeCharCode(r);
      continue;
    }
    if (r == 0x0307) continue; // birleşen nokta
    final folded = _foldRunes[r];
    if (folded != null) {
      b.write(folded);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}


/// URL dostu kısa ad: Türkçe küçük harf, aksan sadeleştirme, tire ile ayırma.
String toSlug(String input) {
  final folded = _asciiFold(toLowerTr(input));
  final b = StringBuffer();
  var pendingDash = false;
  for (final c in folded.codeUnits) {
    final keep = (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39);
    if (!keep) {
      pendingDash = b.isNotEmpty;
      continue;
    }
    if (pendingDash) b.writeCharCode(0x2D);
    pendingDash = false;
    b.writeCharCode(c);
  }
  return b.toString();
}

// --- Diğer ------------------------------------------------------------------------

String timestampToIso(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  final n = int.tryParse(trimmed);
  if (n == null) return 'Geçersiz timestamp: tam sayı bekleniyor';
  // 11+ basamak milisaniye kabul edilir (ör. 1700000000000).
  final digits = trimmed.replaceFirst('-', '').length;
  final ms = digits > 10 ? n : n * 1000;
  try {
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toIso8601String();
  } on RangeError {
    return 'Geçersiz timestamp: tarih aralığı dışında';
  } on ArgumentError {
    return 'Geçersiz timestamp: tarih aralığı dışında';
  }
}

/// Karakter sayısı kullanıcının gördüğü harflerdir (grafem kümeleri);
/// UTF-16 birimi ve UTF-8 bayt sayısı ayrıca verilir.
String wordCount(String input) {
  final graphemes = input.characters.length;
  final words = input.split(_whitespace).where((w) => w.isNotEmpty).length;
  final lines = input.isEmpty ? 0 : _splitLines(input).$1.length;
  final bytes = utf8.encode(input).length;
  return '$graphemes karakter, $words kelime, $lines satır, '
      '${input.runes.length} kod noktası, $bytes bayt (UTF-8)';
}

String _decodeJwtPart(String input, int index) {
  final parts = input.trim().split('.');
  if (parts.length < 2 || parts.length <= index) {
    return 'Geçersiz JWT: ${index == 0 ? 'header' : 'payload'} bölümü yok';
  }
  try {
    var segment = parts[index];
    final rem = segment.length % 4;
    if (rem != 0) segment += '=' * (4 - rem);
    final decoded = utf8.decode(base64Url.decode(segment));
    final json = jsonDecode(decoded);
    return const JsonEncoder.withIndent('  ').convert(json);
  } on FormatException catch (e) {
    return 'JWT decode hatası: ${e.message}';
  }
}

String decodeJwtPayload(String input) => _decodeJwtPart(input, 1);

String decodeJwtHeader(String input) => _decodeJwtPart(input, 0);
