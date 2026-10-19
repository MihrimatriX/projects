import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/legacy_migration.dart';
import '../models/podcast_feed.dart';

class FeedsRepository {
  FeedsRepository(this._db);

  final AppDatabase _db;

  Future<List<PodcastFeed>> load() async {
    await migrateLegacyPrefsIfNeeded(_db);
    final rows = await (_db.select(_db.feeds)..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).get();
    return rows
        .map(
          (r) => PodcastFeed(
            id: r.id,
            title: r.title,
            url: r.url,
            imageUrl: r.imageUrl,
          ),
        )
        .toList();
  }

  Future<void> upsert(PodcastFeed feed) async {
    await _db.into(_db.feeds).insertOnConflictUpdate(
          FeedsCompanion.insert(
            id: feed.id,
            title: feed.title,
            url: feed.url,
            imageUrl: Value(feed.imageUrl),
          ),
        );
  }

  // SQLite yabancı anahtarları varsayılan kapalı (cascade çalışmaz): bölüm
  // önbelleği elle silinir, aksi halde abonelikten çıkılan feed'in satırları kalır.
  Future<void> delete(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.episodes)..where((t) => t.feedId.equals(id))).go();
      await (_db.delete(_db.feeds)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> replaceAll(List<PodcastFeed> feeds) async {
    await _db.transaction(() async {
      await _db.delete(_db.feeds).go();
      for (final f in feeds) {
        await upsert(f);
      }
    });
  }
}
