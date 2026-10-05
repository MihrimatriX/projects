import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http_pkg;
import 'package:xml/xml.dart';

import '../../../core/network/podcast_http.dart';
import '../../../core/player/episode_chapter.dart';

/// Kullanıcıya olduğu gibi gösterilebilen (Türkçe) feed hatası.
class FeedException implements Exception {
  const FeedException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FeedMeta {
  const FeedMeta({this.title, this.imageUrl});

  final String? title;
  final String? imageUrl;
}

class PodcastEpisode {
  const PodcastEpisode({
    required this.title,
    required this.audioUrl,
    this.description,
    this.published,
    this.duration,
    this.localPath,
    this.chapters = const [],
  });

  final String title;
  final String audioUrl;
  final String? description;
  final DateTime? published;
  final Duration? duration;
  final String? localPath;
  final List<EpisodeChapter> chapters;
}

/// http paketi charset belirtilmemiş yanıtları latin1 çözer; RSS'ler neredeyse
/// hep UTF-8 olduğundan Türkçe karakterler bozuluyordu. Charset yoksa UTF-8.
String decodeFeedBody(http_pkg.Response response) {
  final type = response.headers['content-type']?.toLowerCase() ?? '';
  if (type.contains('charset=')) return response.body;
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}

Future<String> _fetchRssBody(String feedUrl, PodcastHttp http) async {
  final uri = Uri.tryParse(feedUrl.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
    throw const FeedException('Geçersiz adres: http:// veya https:// ile başlayan bir RSS adresi girin.');
  }
  final http_pkg.Response response;
  try {
    response = await http.get(feedUrl);
  } on TimeoutException {
    throw const FeedException('Sunucu zamanında yanıt vermedi. Daha sonra tekrar deneyin.');
  } catch (_) {
    throw const FeedException('Bağlantı kurulamadı. İnternet bağlantını kontrol et.');
  }
  if (response.statusCode != 200) {
    throw FeedException('RSS indirilemedi (HTTP ${response.statusCode}).');
  }
  return decodeFeedBody(response);
}

XmlDocument _parseXml(String body) {
  try {
    return XmlDocument.parse(body);
  } on XmlException {
    throw const FeedException('Adres geçerli bir RSS beslemesi döndürmedi (XML okunamadı).');
  }
}

FeedMeta parseFeedMeta(String body) {
  final channel = _parseXml(body).findAllElements('channel').firstOrNull;
  final title = channel?.getElement('title')?.innerText.trim();
  return FeedMeta(
    title: title == null || title.isEmpty ? null : title,
    imageUrl: _parseChannelImage(channel),
  );
}

/// Ağ/parse hatasında boş meta döner (OPML içe aktarma gibi toplu işlemler için).
Future<FeedMeta> fetchFeedMeta(String feedUrl, PodcastHttp http) async {
  try {
    return parseFeedMeta(await _fetchRssBody(feedUrl, http));
  } catch (_) {
    return const FeedMeta();
  }
}

/// Abone olmadan önce: adres erişilebilir, geçerli RSS ve oynatılabilir bölüm içeriyor mu?
/// Hata durumunda [FeedException] fırlatır.
Future<FeedMeta> fetchAndValidateFeed(String feedUrl, PodcastHttp http) async {
  final body = await _fetchRssBody(feedUrl, http);
  parseEpisodes(body);
  return parseFeedMeta(body);
}

Future<String?> fetchFeedTitle(String feedUrl, PodcastHttp http) async {
  final meta = await fetchFeedMeta(feedUrl, http);
  return meta.title;
}

String? _parseChannelImage(XmlElement? channel) {
  if (channel == null) return null;
  for (final el in channel.descendants.whereType<XmlElement>()) {
    // Bölümlerin kendi kapakları (item içindeki itunes:image) kanal kapağı sayılmasın.
    if (el.name.local == 'image' && el.parentElement?.name.local != 'item') {
      // itunes:image -> href niteliği; RSS <image> -> içindeki <url> öğesi.
      final href = el.getAttribute('href') ?? (el.getElement('url') ?? el).innerText.trim();
      if (href.startsWith('http')) return href;
    }
  }
  return null;
}

Future<List<PodcastEpisode>> fetchEpisodes(String feedUrl, PodcastHttp http) async {
  return parseEpisodes(await _fetchRssBody(feedUrl, http));
}

/// RSS gövdesinden en yeni 30 oynatılabilir bölüm. Ses dosyası olmayan
/// (yalnızca web sayfası linki olan) öğeler atlanır.
List<PodcastEpisode> parseEpisodes(String body) {
  final doc = _parseXml(_rssSnippetForItems(body));
  final episodes = <PodcastEpisode>[];

  for (final item in doc.findAllElements('item')) {
    final audioUrl = _audioUrl(item);
    if (audioUrl == null) continue;
    final title = item.getElement('title')?.innerText.trim();

    episodes.add(
      PodcastEpisode(
        title: title == null || title.isEmpty ? 'Bölüm' : title,
        audioUrl: audioUrl,
        description: item.getElement('description')?.innerText.trim(),
        published: parsePubDate(item.getElement('pubDate')?.innerText ?? ''),
        duration: _parseDuration(_findItunesDuration(item)),
        chapters: _parseChapters(item),
      ),
    );
  }

  if (episodes.isEmpty) {
    throw const FeedException('RSS\'te oynatılabilir bölüm bulunamadı.');
  }
  // List.sort kararlı değil: aynı/eksik tarihli bölümler feed sırasını korusun.
  final feedOrder = {for (var i = 0; i < episodes.length; i++) episodes[i]: i};
  int byFeedOrder(PodcastEpisode a, PodcastEpisode b) => feedOrder[a]!.compareTo(feedOrder[b]!);
  episodes.sort((a, b) {
    final ap = a.published;
    final bp = b.published;
    if (ap == null && bp == null) return byFeedOrder(a, b);
    if (ap == null) return 1;
    if (bp == null) return -1;
    final c = bp.compareTo(ap);
    return c != 0 ? c : byFeedOrder(a, b);
  });

  // Eskiden-yeniye sıralı feed'lerde de en yeni 30 bölüm kalsın diye sıralamadan sonra kesilir.
  return episodes.take(30).toList();
}

String? _audioUrl(XmlElement item) {
  for (final el in item.childElements) {
    // <enclosure url=…> (RSS) ya da <media:content url=…> (Media RSS).
    final local = el.name.local;
    if (local != 'enclosure' && local != 'content') continue;
    final url = el.getAttribute('url')?.trim();
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}

/// Buyuk feed'lerde tum XML'i parse etmeyi onler (NPR vb. 2MB+).
String _rssSnippetForItems(String body, {int maxItems = 40}) {
  if (body.length < 200000) return body;
  final channelMatch = RegExp(r'<rss[\s\S]*?<channel\b[^>]*>', caseSensitive: false).firstMatch(body);
  if (channelMatch == null) return body;
  final itemRe = RegExp(r'<item\b[\s\S]*?</item>', caseSensitive: false);
  final sb = StringBuffer(body.substring(0, channelMatch.end));
  var count = 0;
  for (final m in itemRe.allMatches(body, channelMatch.end)) {
    sb.write(m.group(0));
    if (++count >= maxItems) break;
  }
  sb.write('</channel></rss>');
  return sb.toString();
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

const _zoneHours = {
  'GMT': 0, 'UT': 0, 'UTC': 0, 'Z': 0,
  'EST': -5, 'EDT': -4, 'CST': -6, 'CDT': -5,
  'MST': -7, 'MDT': -6, 'PST': -8, 'PDT': -7,
};

/// RFC 822 tarihi (`Tue, 5 Mar 2024 10:00 +0300`; gün adı, saniye ve bölge
/// isteğe bağlı; EST/PDT gibi adlı bölgeler). Olmazsa ISO 8601 denenir.
DateTime? parsePubDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final m = RegExp(
    r'^(?:[A-Za-z]+,?\s*)?(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\.?\s+(\d{2,4})\s+'
    r'(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{2}:?\d{2}|[A-Za-z]+)?',
  ).firstMatch(s);
  if (m == null) return DateTime.tryParse(s)?.toLocal();
  final month = _months[m[2]!.toLowerCase()];
  if (month == null) return null;
  var year = int.parse(m[3]!);
  if (year < 100) year += 2000;
  final utc = DateTime.utc(
    year, month, int.parse(m[1]!), int.parse(m[4]!), int.parse(m[5]!), int.parse(m[6] ?? '0'),
  );
  final zone = m[7];
  var offset = Duration.zero;
  if (zone != null && (zone.startsWith('+') || zone.startsWith('-'))) {
    final d = zone.substring(1).replaceAll(':', '');
    offset = Duration(hours: int.parse(d.substring(0, 2)), minutes: int.parse(d.substring(2)));
    if (zone.startsWith('-')) offset = -offset;
  } else if (zone != null) {
    offset = Duration(hours: _zoneHours[zone.toUpperCase()] ?? 0);
  }
  return utc.subtract(offset).toLocal();
}

String? _findItunesDuration(XmlElement item) {
  for (final el in item.descendants.whereType<XmlElement>()) {
    if (el.name.local == 'duration') return el.innerText.trim();
  }
  return null;
}

List<EpisodeChapter> _parseChapters(XmlElement item) {
  final psc = _collectPscChapters(item);
  if (psc.isNotEmpty) return psc;
  for (final el in item.descendants.whereType<XmlElement>()) {
    if (el.name.local != 'chapters') continue;
    final raw = el.innerText.trim();
    if (raw.startsWith('{') || raw.startsWith('[')) {
      return _chaptersFromJson(raw);
    }
  }
  return [];
}

List<EpisodeChapter> _collectPscChapters(XmlElement item) {
  final chapters = <EpisodeChapter>[];
  for (final el in item.descendants.whereType<XmlElement>()) {
    if (el.name.local != 'chapter') continue;
    final start = _parseChapterStart(el.getAttribute('start') ?? el.getAttribute('startTime'));
    if (start == null) continue;
    chapters.add(EpisodeChapter(title: el.getAttribute('title') ?? 'Bölüm', start: start));
  }
  chapters.sort((a, b) => a.start.compareTo(b.start));
  return chapters;
}

List<EpisodeChapter> _chaptersFromJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    final list = decoded is Map ? (decoded['chapters'] as List?) ?? [] : decoded as List;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final startRaw = (m['start'] as num?) ?? (m['startTime'] as num?) ?? 0;
      final startMs = startRaw > 10000 ? startRaw.toInt() : (startRaw * 1000).toInt();
      return EpisodeChapter(
        title: m['title'] as String? ?? 'Bölüm',
        start: Duration(milliseconds: startMs),
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

// Podlove Simple Chapters: "HH:MM:SS(.mmm)" ya da "MM:SS"; düz sayı = saniye.
Duration? _parseChapterStart(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final sec = double.tryParse(raw);
  if (sec != null) return Duration(milliseconds: (sec * 1000).round());
  final parts = raw.split(':').map(double.tryParse).toList();
  if (parts.any((p) => p == null) || parts.length < 2 || parts.length > 3) return null;
  final total = parts.fold<double>(0, (acc, p) => acc * 60 + p!);
  return Duration(milliseconds: (total * 1000).round());
}

Duration? _parseDuration(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final secs = num.tryParse(raw); // "1834" veya "1834.5" gibi saniye değerleri
  if (secs != null) return Duration(milliseconds: (secs * 1000).round());
  final parts = raw.split(':').map(int.tryParse).toList();
  if (parts.any((p) => p == null)) return null;
  if (parts.length == 3) {
    return Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!);
  }
  if (parts.length == 2) {
    return Duration(minutes: parts[0]!, seconds: parts[1]!);
  }
  return null;
}
