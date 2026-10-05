import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/network/podcast_http_provider.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/player/playback_positions.dart';
import '../data/feeds_repository.dart';
import '../models/podcast_feed.dart';
import '../services/opml_sync_provider.dart';
import '../utils/opml_service.dart';
import '../utils/rss_parser.dart';

final feedsRepositoryProvider = Provider(
  (ref) => FeedsRepository(ref.watch(appDatabaseProvider)),
);

final playbackPositionsProvider = Provider(
  (ref) => PlaybackPositions(ref.watch(appDatabaseProvider)),
);

final feedsProvider =
    AsyncNotifierProvider<FeedsNotifier, List<PodcastFeed>>(FeedsNotifier.new);

class FeedsNotifier extends AsyncNotifier<List<PodcastFeed>> {
  FeedsRepository get _repo => ref.read(feedsRepositoryProvider);

  @override
  Future<List<PodcastFeed>> build() async {
    // Önce klasör senkronu (masaüstü), sonra DB'den güncel liste okunur.
    // Bozuk bir OPML dosyası kütüphanenin açılmasını engellememeli.
    try {
      await syncOpmlFolderIfNeeded();
    } catch (_) {}
    return _repo.load();
  }

  Future<void> add(String title, String url) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) return;

    final current = state.value ?? await _repo.load();
    if (current.any((f) => f.url == trimmedUrl)) {
      throw const FeedException('Bu podcast zaten kütüphanende.');
    }
    // Abone olmadan önce feed doğrulanır: hatalı adres sessizce eklenmesin.
    final meta = await fetchAndValidateFeed(trimmedUrl, ref.read(podcastHttpProvider));
    final resolvedTitle = title.trim().isNotEmpty ? title.trim() : (meta.title ?? 'Podcast');

    final feed = PodcastFeed(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: resolvedTitle,
      url: trimmedUrl,
      imageUrl: meta.imageUrl,
    );
    await _repo.upsert(feed);
    state = AsyncData([feed, ...current]);
  }

  Future<void> remove(String id) async {
    final current = await future;
    await _repo.delete(id);
    state = AsyncData(current.where((f) => f.id != id).toList());
  }

  Future<int> importOpml(String xml) async {
    final entries = parseOpml(xml);
    if (entries.isEmpty) return 0;
    final http = ref.read(podcastHttpProvider);
    // build() sırasında state henüz yüklenmemiş olabilir; mükerrer eklememek için DB'ye bak.
    final current = state.value ?? await _repo.load();
    final existingUrls = current.map((f) => f.url).toSet();
    var added = 0;
    final newFeeds = <PodcastFeed>[];

    for (final e in entries) {
      if (existingUrls.contains(e.url)) continue;
      var title = e.title;
      String? imageUrl;
      if (title.isEmpty || title == 'Podcast') {
        final meta = await fetchFeedMeta(e.url, http);
        title = meta.title ?? e.title;
        imageUrl = meta.imageUrl;
      } else {
        imageUrl = (await fetchFeedMeta(e.url, http)).imageUrl;
      }
      final feed = PodcastFeed(
        id: '${DateTime.now().millisecondsSinceEpoch}$added',
        title: title.isEmpty ? 'Podcast' : title,
        url: e.url,
        imageUrl: imageUrl,
      );
      await _repo.upsert(feed);
      newFeeds.add(feed);
      existingUrls.add(e.url);
      added++;
    }

    if (added > 0) {
      state = AsyncData([...newFeeds, ...current]);
    }
    return added;
  }

  Future<void> syncOpmlFolderIfNeeded() async {
    if (PlatformInfo.isWeb) return;
    final sync = ref.read(opmlSyncServiceProvider);
    final path = await sync.getFolderPath();
    if (path == null) return;
    if (!await sync.shouldSync(path)) return;
    final xml = await sync.readOpmlFromFolder(path);
    if (xml == null) return;
    await importOpml(xml);
    await sync.markSynced(path);
  }

  Future<void> configureOpmlSyncFolder(String? path) async {
    await ref.read(opmlSyncServiceProvider).setFolderPath(path);
    if (path != null) await syncOpmlFolderIfNeeded();
  }
}
