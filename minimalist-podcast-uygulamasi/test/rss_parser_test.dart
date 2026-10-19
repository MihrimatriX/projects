import 'package:flutter_test/flutter_test.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/models/podcast_feed.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/utils/opml_service.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/utils/rss_parser.dart';

import 'fixture_http.dart';

const _basic = 'https://ornek.test/feed.xml';

Matcher _feedError(String part) =>
    throwsA(isA<FeedException>().having((e) => e.message, 'message', contains(part)));

void main() {
  group('parseEpisodes (yerel fixture)', () {
    late List<PodcastEpisode> eps;
    setUp(() => eps = parseEpisodes(FixtureHttp.fixture('feed_basic.xml')));

    test('ses dosyası olmayan öğe atlanır, en yeni önce sıralanır', () {
      expect(eps.map((e) => e.audioUrl), [
        'https://ornek.test/3.mp3', // 6 Mart 15:00Z (EST)
        'https://ornek.test/2.m4a', // 5 Mart 10:30Z (+0300), media:content
        'https://ornek.test/1.mp3', // 5 Mart 08:00Z
        'https://ornek.test/tarihsiz.mp3', // tarihsiz sona
      ]);
      expect(eps.last.title, 'Bölüm');
      expect(eps.last.published, isNull);
      expect(eps.first.title, 'Bölüm 3: Şimdiki zaman');
    });

    test('süre biçimleri: MM:SS, HH:MM:SS, saniye', () {
      expect(eps[0].duration, const Duration(minutes: 45, seconds: 10));
      expect(eps[1].duration, const Duration(seconds: 1834));
      expect(eps[2].duration, const Duration(hours: 1, minutes: 2, seconds: 3));
    });

    test('Podlove bölüm başlangıçları (kesirli saniye, düz saniye)', () {
      expect(eps[0].chapters.map((c) => c.start.inMilliseconds), [0, 62500, 90000]);
      expect(eps[0].chapters.map((c) => c.title), ['Giriş', 'Konu', 'Kapanış']);
    });

    test('kanal bilgisi: CDATA başlık, bölüm kapağı değil kanal kapağı', () {
      final meta = parseFeedMeta(FixtureHttp.fixture('feed_basic.xml'));
      expect(meta.title, 'Çay & Kod — Türkçe Yazılım Sohbetleri');
      expect(meta.imageUrl, 'https://ornek.test/kapak.jpg');
    });

    test('büyük feed (200 KB+) yalnızca ilk öğeler ayrıştırılarak okunur', () {
      final items = List.generate(
        120,
        (i) => '<item><title>B$i</title><description>${'x' * 2000}</description>'
            '<pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate>'
            '<enclosure url="https://ornek.test/b$i.mp3"/></item>',
      ).join();
      final body = '<?xml version="1.0"?><rss version="2.0"><channel><title>Dev</title>$items</channel></rss>';
      expect(body.length, greaterThan(200000));
      final big = parseEpisodes(body);
      expect(big, hasLength(30));
      expect(big.first.audioUrl, 'https://ornek.test/b0.mp3');
    });
  });

  test('parsePubDate: RFC 822 çeşitleri ve ISO 8601', () {
    DateTime? utc(String s) => parsePubDate(s)?.toUtc();
    expect(utc('Tue, 05 Mar 2024 13:30:00 +0300'), DateTime.utc(2024, 3, 5, 10, 30));
    expect(utc('Wed, 06 Mar 2024 10:00 EST'), DateTime.utc(2024, 3, 6, 15));
    expect(utc('5 Mar 2024 08:00:00 GMT'), DateTime.utc(2024, 3, 5, 8));
    expect(utc('Tue, 5 March 24 08:00:00 -05:00'), DateTime.utc(2024, 3, 5, 13));
    expect(utc('2024-03-05T08:00:00Z'), DateTime.utc(2024, 3, 5, 8));
    expect(parsePubDate('gecersiz tarih'), isNull);
    expect(parsePubDate(''), isNull);
  });

  group('fetch + doğrulama (sahte HTTP, canlı internet yok)', () {
    final http = FixtureHttp({
      _basic: 'feed_basic.xml',
      'https://ornek.test/html': 'feed_not_rss.html',
      'https://ornek.test/broken': 'feed_broken.xml',
      'https://ornek.test/bos': 'feed_no_episodes.xml',
    });
    tearDown(() => http.failWith = null);

    test('charset belirtilmeyen yanıt UTF-8 çözülür (Türkçe bozulmaz)', () async {
      final meta = await fetchAndValidateFeed(_basic, http);
      expect(meta.title, startsWith('Çay & Kod'));
      final eps = await fetchEpisodes(_basic, http);
      expect(eps.first.title, 'Bölüm 3: Şimdiki zaman');
    });

    test('anlaşılır Türkçe hatalar', () async {
      expect(fetchAndValidateFeed('https://ornek.test/html', http), _feedError('XML'));
      expect(fetchAndValidateFeed('https://ornek.test/broken', http), _feedError('XML'));
      expect(fetchAndValidateFeed('https://ornek.test/bos', http), _feedError('bölüm bulunamadı'));
      expect(fetchAndValidateFeed('https://ornek.test/yok', http), _feedError('HTTP 404'));
      expect(fetchAndValidateFeed('ornek.test/feed', http), _feedError('Geçersiz adres'));
      expect(fetchAndValidateFeed('ftp://ornek.test/feed', http), _feedError('Geçersiz adres'));
    });

    test('çevrimdışı ve zaman aşımı', () async {
      http.failWith = offline;
      await expectLater(fetchEpisodes(_basic, http), _feedError('Bağlantı kurulamadı'));
      http.failWith = timeout;
      await expectLater(fetchEpisodes(_basic, http), _feedError('zamanında yanıt vermedi'));
      // Toplu içe aktarmada meta hatası sessizce boş döner.
      expect((await fetchFeedMeta(_basic, http)).title, isNull);
    });
  });

  test('OPML: iç içe, type eksik/büyük harf, tekrarlar', () {
    final entries = parseOpml(FixtureHttp.fixture('subscriptions.opml'));
    expect(entries.map((e) => e.url), [
      'https://ornek.test/bir.xml',
      'https://ornek.test/iki.xml',
      'https://ornek.test/uc.xml',
    ]);
    final xml = exportOpml(const [
      PodcastFeed(id: '1', title: 'A & "B" <C>', url: 'https://x.test/?a=1&b=2'),
    ]);
    final back = parseOpml(xml).single;
    expect(back.title, 'A & "B" <C>');
    expect(back.url, 'https://x.test/?a=1&b=2');
  });
}
