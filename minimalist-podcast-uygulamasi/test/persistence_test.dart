import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimalist_podcast_uygulamasi/core/database/app_database.dart';
import 'package:minimalist_podcast_uygulamasi/core/database/database_provider.dart';
import 'package:minimalist_podcast_uygulamasi/core/network/podcast_http_provider.dart';
import 'package:minimalist_podcast_uygulamasi/core/player/now_playing.dart';
import 'package:minimalist_podcast_uygulamasi/core/player/playback_positions.dart';
import 'package:minimalist_podcast_uygulamasi/core/player/queue_provider.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/data/episodes_repository.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/providers/feeds_provider.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/utils/rss_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_http.dart';

const _feedUrl = 'https://ornek.test/feed.xml';

void main() {
  late AppDatabase db;
  late FixtureHttp http;

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      podcastHttpProvider.overrideWithValue(http),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    // Eski SharedPreferences göçü (demo feed ekler) bitmiş sayılır.
    SharedPreferences.setMockInitialValues({'drift_migrated_v1': true});
    db = AppDatabase(NativeDatabase.memory());
    http = FixtureHttp({_feedUrl: 'feed_basic.xml', 'https://ornek.test/bos': 'feed_no_episodes.xml'});
  });
  tearDown(() => db.close());

  group('abonelikler', () {
    test('ekle: feed doğrulanır, başlık/kapak RSS\'ten, kalıcı', () async {
      await container().read(feedsProvider.notifier).add('', _feedUrl);
      final feeds = await container().read(feedsProvider.future); // yeni kapsayıcı = yeniden açılış
      expect(feeds.single.title, startsWith('Çay & Kod'));
      expect(feeds.single.imageUrl, 'https://ornek.test/kapak.jpg');
    });

    test('mükerrer, hatalı ve çevrimdışı ekleme reddedilir; hiçbir şey yazılmaz', () async {
      final n = container().read(feedsProvider.notifier);
      await expectLater(n.add('', 'https://ornek.test/bos'), throwsA(isA<FeedException>()));
      await expectLater(n.add('', 'https://ornek.test/404'), throwsA(isA<FeedException>()));
      http.failWith = offline;
      await expectLater(n.add('', _feedUrl), throwsA(isA<FeedException>()));
      expect(await db.select(db.feeds).get(), isEmpty);
      http.failWith = null;
      await n.add('', _feedUrl);
      await expectLater(
        n.add('', _feedUrl),
        throwsA(isA<FeedException>().having((e) => e.message, 'm', contains('zaten'))),
      );
      expect(await db.select(db.feeds).get(), hasLength(1));
    });

    test('abonelikten çıkınca bölüm önbelleği de silinir', () async {
      final c = container();
      await c.read(feedsProvider.notifier).add('Elle', _feedUrl);
      final feed = (await c.read(feedsProvider.future)).single;
      expect(feed.title, 'Elle');
      await EpisodesRepository(db).getEpisodes(feedId: feed.id, feedUrl: feed.url, http: http);
      expect(await db.select(db.episodes).get(), hasLength(4));
      await c.read(feedsProvider.notifier).remove(feed.id);
      expect(await c.read(feedsProvider.future), isEmpty);
      expect(await db.select(db.episodes).get(), isEmpty);
    });

    test('OPML içe aktarma: yalnızca yeni adresler, ağ hatası engel değil', () async {
      final n = container().read(feedsProvider.notifier);
      await n.add('', 'https://ornek.test/feed.xml');
      http.routes['https://ornek.test/bir.xml'] = 'feed_basic.xml';
      final added = await n.importOpml(FixtureHttp.fixture('subscriptions.opml'));
      expect(added, 3); // bir, iki (404 -> OPML başlığı), uc
      final titles = (await db.select(db.feeds).get()).map((f) => f.title).toSet();
      expect(titles, containsAll(['Bir', 'Iki', 'Tipsiz']));
      expect(await n.importOpml(FixtureHttp.fixture('subscriptions.opml')), 0);
    });
  });

  group('bölüm önbelleği ve çevrimdışı', () {
    test('taze önbellek ağsız döner; bayat önbellek çevrimdışıyken yine gösterilir', () async {
      final repo = EpisodesRepository(db);
      await db.into(db.feeds).insert(FeedsCompanion.insert(id: 'f', title: 'F', url: _feedUrl));
      final first = await repo.getEpisodes(feedId: 'f', feedUrl: _feedUrl, http: http);
      expect(first, hasLength(4));
      expect(first.first.chapters, hasLength(3)); // JSON'a yazılıp geri okundu

      http.failWith = offline;
      final before = http.requests;
      expect(await repo.getEpisodes(feedId: 'f', feedUrl: _feedUrl, http: http), hasLength(4));
      expect(http.requests, before, reason: 'taze önbellekte istek yok');

      await db.update(db.episodes).write(EpisodesCompanion(fetchedAt: Value(DateTime(2000))));
      expect(await repo.getEpisodes(feedId: 'f', feedUrl: _feedUrl, http: http), hasLength(4));

      // Elle yenileme çevrimdışıyken anlaşılır hata verir, önbelleği silmez.
      await expectLater(
        repo.getEpisodes(feedId: 'f', feedUrl: _feedUrl, http: http, forceRefresh: true),
        throwsA(isA<FeedException>()),
      );
      expect(await db.select(db.episodes).get(), hasLength(4));
    });

    test('önbellek yokken çevrimdışı: hata', () async {
      http.failWith = offline;
      await expectLater(
        EpisodesRepository(db).getEpisodes(feedId: 'x', feedUrl: _feedUrl, http: http),
        throwsA(isA<FeedException>()),
      );
    });
  });

  group('oynatma durumu', () {
    test('konum kaydı, %92 sonrası dinlendi, devam listesi', () async {
      final p = PlaybackPositions(db);
      const total = Duration(minutes: 10);
      await p.save('a', const Duration(minutes: 3), totalDuration: total);
      await p.save('b', const Duration(minutes: 9, seconds: 40), totalDuration: total);
      await p.save('c', const Duration(seconds: 1)); // çok kısa, süre bilinmiyor: yok sayılır
      expect(await p.load('a'), const Duration(minutes: 3));
      expect(await p.load('b'), isNull);
      expect((await p.getProgress('b')).completed, isTrue);
      expect((await p.getProgress('c')).position, isNull);
      final recent = await p.getRecentInProgress();
      expect(recent.map((r) => r.audioUrl), ['a']);
      await p.markCompleted('a');
      expect(await p.load('a'), isNull);
      expect(await p.getRecentInProgress(), isEmpty);
    });

    test('dinleme sırası kalıcı; sıralama ve silme yeniden açılışta korunur', () async {
      NowPlaying ep(String id) =>
          NowPlaying(episodeTitle: id, audioUrl: 'https://ornek.test/$id.mp3', podcastTitle: 'P', feedId: 'f');
      final first = container().read(playQueueProvider.notifier);
      await first.add(ep('1'));
      await first.add(ep('2'));
      // Yeniden açılışta, sıra DB'den yüklenmeden ekleme: mevcut öğeler kaybolmamalı.
      final q = container().read(playQueueProvider.notifier);
      await q.add(ep('3'));
      await q.add(ep('1')); // tekrar eklenmez
      await q.reorder(2, 0);
      await q.remove('https://ornek.test/2.mp3');
      final reopened = await container().read(playQueueProvider.future);
      expect(reopened.map((e) => e.episodeTitle), ['3', '1']);
    });
  });
}
