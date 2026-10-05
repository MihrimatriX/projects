import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/legacy_migration.dart';

class EpisodeProgress {
  const EpisodeProgress({this.position, this.completed = false});

  final Duration? position;
  final bool completed;
}

class PlaybackPositions {
  PlaybackPositions(this._db);

  final AppDatabase _db;

  Future<EpisodeProgress> getProgress(String audioUrl) async {
    await migrateLegacyPrefsIfNeeded(_db);
    final row = await (_db.select(_db.playbackPositionsTable)
          ..where((t) => t.audioUrl.equals(audioUrl)))
        .getSingleOrNull();
    if (row == null) return const EpisodeProgress();
    return EpisodeProgress(
      position: row.positionMs > 0 ? Duration(milliseconds: row.positionMs) : null,
      completed: row.completed,
    );
  }

  Future<Map<String, EpisodeProgress>> getProgressForUrls(List<String> urls) async {
    await migrateLegacyPrefsIfNeeded(_db);
    if (urls.isEmpty) return {};
    final rows = await (_db.select(_db.playbackPositionsTable)
          ..where((t) => t.audioUrl.isIn(urls)))
        .get();
    return {
      for (final r in rows)
        r.audioUrl: EpisodeProgress(
          position: r.positionMs > 0 ? Duration(milliseconds: r.positionMs) : null,
          completed: r.completed,
        ),
    };
  }

  Future<Duration?> load(String audioUrl) async {
    final p = await getProgress(audioUrl);
    return p.completed ? null : p.position;
  }

  Future<void> save(String audioUrl, Duration position, {Duration? totalDuration}) async {
    await migrateLegacyPrefsIfNeeded(_db);
    if (position.inSeconds < 3 && totalDuration == null) return;

    // Sürenin %92'si dinlendiyse bölüm "dinlendi" sayılır ve konum sıfırlanır.
    var completed = false;
    if (totalDuration != null && totalDuration.inSeconds > 0) {
      completed = position.inMilliseconds >= totalDuration.inMilliseconds * 0.92;
    }

    await _db.into(_db.playbackPositionsTable).insertOnConflictUpdate(
          PlaybackPositionsTableCompanion.insert(
            audioUrl: audioUrl,
            positionMs: completed ? 0 : position.inMilliseconds,
            completed: Value(completed),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Son dinlenen, yarım kalmış bölümler (devam et kartları için).
  Future<List<({String audioUrl, EpisodeProgress progress})>> getRecentInProgress({
    int limit = 5,
  }) async {
    await migrateLegacyPrefsIfNeeded(_db);
    final rows = await (_db.select(_db.playbackPositionsTable)
          ..where(
            (t) => t.completed.equals(false) & t.positionMs.isBiggerThanValue(3000),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();
    return [
      for (final r in rows)
        (
          audioUrl: r.audioUrl,
          progress: EpisodeProgress(
            position: Duration(milliseconds: r.positionMs),
            completed: false,
          ),
        ),
    ];
  }

  Future<void> markCompleted(String audioUrl) async {
    await migrateLegacyPrefsIfNeeded(_db);
    await _db.into(_db.playbackPositionsTable).insertOnConflictUpdate(
          PlaybackPositionsTableCompanion.insert(
            audioUrl: audioUrl,
            positionMs: 0,
            completed: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
