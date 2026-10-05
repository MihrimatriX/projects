import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/episodes_repository.dart';
import '../models/podcast_feed.dart';
import '../utils/rss_parser.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/network/podcast_http_provider.dart';

final episodesRepositoryProvider = Provider(
  (ref) => EpisodesRepository(ref.watch(appDatabaseProvider)),
);

final episodesProvider =
    FutureProvider.autoDispose.family<List<PodcastEpisode>, PodcastFeed>((ref, feed) {
  final http = ref.watch(podcastHttpProvider);
  return ref.read(episodesRepositoryProvider).getEpisodes(
        feedId: feed.id,
        feedUrl: feed.url,
        http: http,
      );
});
