import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/podcast_http_provider.dart';
import '../data/episodes_repository.dart';
import '../models/podcast_feed.dart';
import '../../../core/network/podcast_http.dart';
import '../providers/episodes_provider.dart';
import '../providers/feeds_provider.dart';

class FeedRefreshService {
  FeedRefreshService(this._episodesRepo);

  final EpisodesRepository _episodesRepo;

  Future<int> refreshAll(List<PodcastFeed> feeds, PodcastHttp http) async {
    var ok = 0;
    for (final feed in feeds) {
      try {
        await _episodesRepo.getEpisodes(
          feedId: feed.id,
          feedUrl: feed.url,
          http: http,
          forceRefresh: true,
        );
        ok++;
      } catch (_) {}
    }
    return ok;
  }
}

final feedRefreshServiceProvider = Provider((ref) {
  return FeedRefreshService(ref.watch(episodesRepositoryProvider));
});

final refreshAllFeedsProvider = FutureProvider.autoDispose<int>((ref) async {
  final feeds = await ref.watch(feedsProvider.future);
  final http = ref.read(podcastHttpProvider);
  final count = await ref.read(feedRefreshServiceProvider).refreshAll(feeds, http);
  for (final f in feeds) {
    ref.invalidate(episodesProvider(f));
  }
  return count;
});
