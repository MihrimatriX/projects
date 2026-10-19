const _monthsTr = [
  'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
  'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
];

String _shortDate(DateTime dt) => '${dt.day} ${_monthsTr[dt.month - 1]}';

String formatRelativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Az önce';
  if (diff.inHours < 1) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays == 1) return 'dün';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return _shortDate(dt);
}

String shortenPath(String path) {
  final home = RegExp(r'^[A-Za-z]:\\Users\\[^\\]+');
  if (home.hasMatch(path)) {
    return path.replaceFirst(home, '~').replaceAll(r'\', '/');
  }
  return path.replaceAll(r'\', '/');
}

int countWords(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return 0;
  return trimmed.split(RegExp(r'\s+')).length;
}

int readingMinutes(String text) {
  final words = countWords(text);
  return words == 0 ? 0 : (words / 200).ceil().clamp(1, 9999);
}

String formatNoteDate(DateTime dt) {
  final today = DateTime.now();
  if (dt.year == today.year &&
      dt.month == today.month &&
      dt.day == today.day) {
    return 'Bugün';
  }
  return _shortDate(dt);
}

/// Önizleme için baştaki YAML ön bilgisini atar. Yalnızca ilk satır tam olarak
/// `---` ise ve kapanış satırı (`---` ya da `...`) varsa; aksi halde metin aynen
/// döner (ör. belge yatay çizgiyle başlıyorsa içerik yutulmaz). BOM ve CRLF desteklenir.
String stripFrontMatter(String text) {
  final lines = text.replaceFirst('\uFEFF', '').split('\n');
  if (lines.isEmpty || lines.first.trimRight() != '---') return text;
  for (var i = 1; i < lines.length; i++) {
    final l = lines[i].trimRight();
    if (l == '---' || l == '...') {
      return lines.skip(i + 1).join('\n').trimLeft();
    }
  }
  return text;
}

/// Türkçe duyarlı, büyük/küçük harf ve i/ı/İ/I farkını yok sayan arama anahtarı.
String foldForSearch(String s) => s
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .toLowerCase()
    .replaceAll('ı', 'i');

/// Dosya adında Windows'ta geçersiz karakterleri ayıklar.
String safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '').trim();
  return cleaned.isEmpty ? 'not' : cleaned;
}
