import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/player/playback_positions.dart';
import '../../../core/player/queue_repository.dart';
import '../models/podcast_feed.dart';
import '../utils/rss_parser.dart';
import 'feeds_provider.dart';

class ContinueListeningEntry {
  const ContinueListeningEntry({
    required this.feed,
    required this.episode,
    required this.progress,
  });

  final PodcastFeed feed;
  final PodcastEpisode episode;
  final EpisodeProgress progress;
}

final continueListeningProvider = FutureProvider<List<ContinueListeningEntry>>((ref) async {
  final feeds = ref.watch(feedsProvider).value ?? [];
  if (feeds.isEmpty) return [];

  final recent = await ref.read(playbackPositionsProvider).getRecentInProgress(limit: 5);
  if (recent.isEmpty) return [];

  final db = ref.read(appDatabaseProvider);
  final feedById = {for (final f in feeds) f.id: f};
  final entries = <ContinueListeningEntry>[];

  for (final item in recent) {
    final row = await (db.select(db.episodes)
          ..where((t) => t.audioUrl.equals(item.audioUrl)))
        .getSingleOrNull();
    if (row == null) continue;
    final feed = feedById[row.feedId];
    if (feed == null) continue;
    entries.add(
      ContinueListeningEntry(
        feed: feed,
        episode: PodcastEpisode(
          title: row.title,
          audioUrl: row.audioUrl,
          description: row.description,
          published: row.published,
          duration: row.durationMs != null ? Duration(milliseconds: row.durationMs!) : null,
          localPath: row.localPath,
          chapters: chaptersFromJson(row.chaptersJson),
        ),
        progress: item.progress,
      ),
    );
  }
  return entries;
});
