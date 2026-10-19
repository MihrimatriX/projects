import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'episode_chapter.dart';
import 'now_playing.dart';

List<EpisodeChapter> chaptersFromJson(String? json) {
  if (json == null || json.isEmpty) return [];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) {
          final m = e as Map<String, dynamic>;
          return EpisodeChapter(
            title: m['title'] as String? ?? 'Bölüm',
            start: Duration(milliseconds: (m['startMs'] as num).toInt()),
          );
        })
        .toList();
  } catch (_) {
    return [];
  }
}

String chaptersToJson(List<EpisodeChapter> chapters) {
  return jsonEncode(
    chapters
        .map((c) => {'title': c.title, 'startMs': c.start.inMilliseconds})
        .toList(),
  );
}

class QueueRepository {
  QueueRepository(this._db);

  final AppDatabase _db;

  Future<List<NowPlaying>> loadQueue() async {
    final rows = await (_db.select(_db.playQueueTable)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    return rows
        .map(
          (r) => NowPlaying(
            episodeTitle: r.episodeTitle,
            audioUrl: r.audioUrl,
            podcastTitle: r.podcastTitle,
            feedId: r.feedId,
            duration: r.durationMs != null ? Duration(milliseconds: r.durationMs!) : null,
            localPath: r.localPath,
            chapters: chaptersFromJson(r.chaptersJson),
          ),
        )
        .toList();
  }

  Future<void> replaceQueue(List<NowPlaying> items) async {
    await _db.transaction(() async {
      await _db.delete(_db.playQueueTable).go();
      for (final item in items) {
        await _db.into(_db.playQueueTable).insert(
              PlayQueueTableCompanion.insert(
                audioUrl: item.audioUrl,
                episodeTitle: item.episodeTitle,
                podcastTitle: item.podcastTitle,
                feedId: item.feedId,
                durationMs: Value(item.duration?.inMilliseconds),
                localPath: Value(item.localPath),
                chaptersJson: Value(
                  item.chapters.isEmpty ? null : chaptersToJson(item.chapters),
                ),
              ),
            );
      }
    });
  }

  Future<void> add(NowPlaying item) async {
    await _db.into(_db.playQueueTable).insert(
          PlayQueueTableCompanion.insert(
            audioUrl: item.audioUrl,
            episodeTitle: item.episodeTitle,
            podcastTitle: item.podcastTitle,
            feedId: item.feedId,
            durationMs: Value(item.duration?.inMilliseconds),
            localPath: Value(item.localPath),
            chaptersJson: Value(
              item.chapters.isEmpty ? null : chaptersToJson(item.chapters),
            ),
          ),
        );
  }

  Future<void> removeByAudioUrl(String audioUrl) async {
    await (_db.delete(_db.playQueueTable)..where((t) => t.audioUrl.equals(audioUrl))).go();
  }

  Future<void> clear() async {
    await _db.delete(_db.playQueueTable).go();
  }
}
