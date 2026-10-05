import 'package:xml/xml.dart';

import '../models/podcast_feed.dart';

String exportOpml(List<PodcastFeed> feeds) {
  final outlines = feeds
      .map(
        (f) =>
            '    <outline type="rss" text="${_escape(f.title)}" xmlUrl="${_escape(f.url)}" />',
      )
      .join('\n');

  return '''<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
  <head><title>Minimal Podcast</title></head>
  <body>
$outlines
  </body>
</opml>''';
}

List<({String title, String url})> parseOpml(String xml) {
  final doc = XmlDocument.parse(xml);
  final results = <({String title, String url})>[];

  void walk(XmlElement el) {
    // Bazı uygulamalar type="RSS" yazar ya da type'ı hiç koymaz; xmlUrl yeterli.
    final type = el.getAttribute('type')?.toLowerCase();
    final xmlUrl = el.getAttribute('xmlUrl') ?? el.getAttribute('xmlurl');
    if ((type == null || type == 'rss') && xmlUrl != null && xmlUrl.trim().isNotEmpty) {
      final title = el.getAttribute('text') ?? el.getAttribute('title') ?? 'Podcast';
      results.add((title: title.trim(), url: xmlUrl.trim()));
    }
    for (final child in el.childElements) {
      walk(child);
    }
  }

  for (final el in doc.findAllElements('outline')) {
    walk(el);
  }

  final seen = <String>{};
  return results.where((e) => seen.add(e.url)).toList();
}

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('"', '&quot;').replaceAll('<', '&lt;');
