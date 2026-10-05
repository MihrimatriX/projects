import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

const _userAgent = 'MinimalPodcast/1.0';

/// Yanit vermeyen sunucu ekrani sonsuza dek 'yukleniyor'da birakmasin.
const kHttpTimeout = Duration(seconds: 20);

/// Web'de sirayla denenen CORS proxy tabanlari (run.ps1 yerel proxy ile baslar).
const kWebCorsProxyFallbacks = [
  'http://localhost:8766/proxy?url=',
  'https://corsproxy.io/?url=',
  'https://api.allorigins.win/raw?url=',
];

/// Web'de CORS icin proxy tabani. Bos birakilirsa fallback zinciri kullanilir.
class PodcastHttp {
  PodcastHttp({this.corsProxyBase, List<String>? fallbacks})
      : _fallbacks = fallbacks ?? kWebCorsProxyFallbacks;

  final String? corsProxyBase;
  final List<String> _fallbacks;
  String? _lastWorkingProxy;

  List<String> get _proxyChain {
    if (!kIsWeb) return const [];
    final chain = <String>[];
    void add(String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty && !chain.contains(trimmed)) {
        chain.add(trimmed);
      }
    }

    add(corsProxyBase);
    add(_lastWorkingProxy);
    for (final proxy in _fallbacks) {
      add(proxy);
    }
    return chain;
  }

  Uri _proxyUri(Uri uri, String base) {
    final encoded = Uri.encodeComponent(uri.toString());
    if (base.contains('{url}')) {
      return Uri.parse(base.replaceAll('{url}', encoded));
    }
    final sep = base.endsWith('=') || base.endsWith('?')
        ? ''
        : base.contains('?')
            ? '&url='
            : '?url=';
    return Uri.parse('$base$sep$encoded');
  }

  String resolveUrl(String url) {
    final uri = Uri.parse(url.trim());
    if (!kIsWeb) return uri.toString();
    final proxy = _lastWorkingProxy ?? corsProxyBase ?? _fallbacks.first;
    return _proxyUri(uri, proxy).toString();
  }

  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    final uri = Uri.parse(url.trim());
    final hdrs = {'User-Agent': _userAgent, ...?headers};

    if (!kIsWeb) {
      return http.get(uri, headers: hdrs).timeout(kHttpTimeout);
    }

    Object? lastError;
    for (final proxy in _proxyChain) {
      try {
        final response = await http.get(_proxyUri(uri, proxy), headers: hdrs).timeout(kHttpTimeout);
        if (response.statusCode >= 200 && response.statusCode < 400) {
          _lastWorkingProxy = proxy;
          return response;
        }
        lastError = Exception('HTTP ${response.statusCode} ($proxy)');
      } catch (e) {
        lastError = e;
      }
    }

    throw lastError ?? Exception('Failed to fetch $url');
  }
}
