import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/podcast_http.dart';
import '../../../core/player/queue_repository.dart';
import '../utils/rss_parser.dart';

const _cacheMaxAge = Duration(hours: 6);

class EpisodesRepository {
  EpisodesRepository(this._db);

  final AppDatabase _db;

  Future<List<PodcastEpisode>> getEpisodes({
    required String feedId,
    required String feedUrl,
    required PodcastHttp http,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _loadCached(feedId);
      if (cached.isNotEmpty && await _isCacheFresh(feedId)) {
        return cached;
      }
    }

    final List<PodcastEpisode> fresh;
    try {
      fresh = await fetchEpisodes(feedUrl, http);
    } catch (_) {
      // Ağ yoksa (offline) eski önbellek, hata ekranından iyidir.
      final cached = forceRefresh ? const <PodcastEpisode>[] : await _loadCached(feedId);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
    await _cacheEpisodes(feedId, fresh);
    return _loadCached(feedId);
  }

  Future<List<PodcastEpisode>> _loadCached(String feedId) async {
    final rows = await (_db.select(_db.episodes)
          ..where((t) => t.feedId.equals(feedId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();

    return rows
        .map(
          (r) => PodcastEpisode(
            title: r.title,
            audioUrl: r.audioUrl,
            description: r.description,
            published: r.published,
            duration: r.durationMs != null ? Duration(milliseconds: r.durationMs!) : null,
            localPath: r.localPath,
            chapters: chaptersFromJson(r.chaptersJson),
          ),
        )
        .toList();
  }

  Future<bool> _isCacheFresh(String feedId) async {
    final row = await (_db.selectOnly(_db.episodes)
          ..addColumns([_db.episodes.fetchedAt.max()])
          ..where(_db.episodes.feedId.equals(feedId)))
        .getSingleOrNull();
    final latest = row?.read(_db.episodes.fetchedAt.max());
    if (latest == null) return false;
    return DateTime.now().difference(latest) < _cacheMaxAge;
  }

  Future<void> _cacheEpisodes(String feedId, List<PodcastEpisode> episodes) async {
    final existing = await (_db.select(_db.episodes)
          ..where((t) => t.feedId.equals(feedId)))
        .get();
    final localByUrl = {for (final r in existing) r.audioUrl: r.localPath};
    final chaptersByUrl = {for (final r in existing) r.audioUrl: r.chaptersJson};

    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(_db.episodes)..where((t) => t.feedId.equals(feedId))).go();
      var order = 0;
      for (final ep in episodes) {
        // Aynı ses URL'i feed içinde tekrar edebilir ya da başka bir feed'de olabilir
        // (PK = audioUrl); düz insert UNIQUE hatasıyla tüm yenilemeyi bozuyordu.
        await _db.into(_db.episodes).insertOnConflictUpdate(
              EpisodesCompanion.insert(
                audioUrl: ep.audioUrl,
                feedId: feedId,
                title: ep.title,
                description: Value(ep.description),
                published: Value(ep.published),
                durationMs: Value(ep.duration?.inMilliseconds),
                sortOrder: order++,
                fetchedAt: now,
                localPath: Value(localByUrl[ep.audioUrl]),
                chaptersJson: Value(
                  ep.chapters.isNotEmpty
                      ? chaptersToJson(ep.chapters)
                      : chaptersByUrl[ep.audioUrl],
                ),
              ),
            );
      }
    });
  }
}
