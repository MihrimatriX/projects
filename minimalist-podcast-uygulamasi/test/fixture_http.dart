import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:minimalist_podcast_uygulamasi/core/network/podcast_http.dart';

/// Testlerde canlı internet yerine `test/fixtures` altındaki dosyaları döner.
/// [routes]: URL -> fixture dosya adı. Bilinmeyen URL -> 404.
class FixtureHttp extends PodcastHttp {
  FixtureHttp(this.routes);

  final Map<String, String> routes;

  /// null değilse her istek bu hatayı fırlatır (çevrimdışı / zaman aşımı).
  Object? failWith;
  int requests = 0;

  static String fixture(String name) =>
      File('test/fixtures/$name').readAsStringSync();

  @override
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    requests++;
    final err = failWith;
    if (err != null) throw err;
    final name = routes[url];
    if (name == null) return http.Response('yok', 404);
    // Charset belirtilmemiş içerik türü: gövde UTF-8 çözülmeli.
    return http.Response.bytes(
      File('test/fixtures/$name').readAsBytesSync(),
      200,
      headers: {'content-type': 'application/rss+xml'},
    );
  }
}

const offline = SocketException('Failed host lookup');
final timeout = TimeoutException('yavaş');
