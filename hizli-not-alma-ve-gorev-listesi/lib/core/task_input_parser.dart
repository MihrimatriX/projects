/// Hızlı ekleme satırından etiket ve bağlam çıkarır.
/// Örnek: "#urgent @ev Market al" → title: "Market al", tags: [urgent], contexts: [ev]
class ParsedTaskInput {
  const ParsedTaskInput({
    required this.title,
    this.hashTags = const [],
    this.contexts = const [],
  });

  final String title;
  final List<String> hashTags;
  final List<String> contexts;

  List<String> get allTagNames => [
        ...hashTags.map((t) => '#$t'),
        ...contexts.map((c) => '@$c'),
      ];
}

final _hashTag = RegExp(r'#([\wğüşıöçĞÜŞİÖÇ]+)');
final _context = RegExp(r'@([\wğüşıöçĞÜŞİÖÇ]+)');

ParsedTaskInput parseTaskInput(String raw) {
  final hashTags = <String>[];
  final contexts = <String>[];

  for (final m in _hashTag.allMatches(raw)) {
    hashTags.add(m.group(1)!);
  }
  for (final m in _context.allMatches(raw)) {
    contexts.add(m.group(1)!);
  }

  var title = raw;
  title = title.replaceAll(_hashTag, '');
  title = title.replaceAll(_context, '');
  title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

  return ParsedTaskInput(
    title: title,
    hashTags: hashTags,
    contexts: contexts,
  );
}
