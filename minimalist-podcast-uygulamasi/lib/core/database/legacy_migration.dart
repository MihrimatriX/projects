import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';

const _feedsKey = 'feeds_v1';
const _positionsKey = 'playback_positions_v1';
const _migratedFlag = 'drift_migrated_v1';

Future<void> migrateLegacyPrefsIfNeeded(AppDatabase db) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_migratedFlag) == true) return;

  final feedRaw = prefs.getString(_feedsKey);
  if (feedRaw != null) {
    final list = jsonDecode(feedRaw) as List<dynamic>;
    for (final item in list) {
      final map = item as Map<String, dynamic>;
      await db.into(db.feeds).insertOnConflictUpdate(
            FeedsCompanion.insert(
              id: map['id'] as String,
              title: map['title'] as String,
              url: map['url'] as String,
            ),
          );
    }
  } else {
    await db.into(db.feeds).insertOnConflictUpdate(
          FeedsCompanion.insert(
            id: 'demo',
            title: 'NPR News Now',
            url: 'https://feeds.npr.org/510313/podcast.xml',
          ),
        );
  }

  final posRaw = prefs.getString(_positionsKey);
  if (posRaw != null) {
    final map = jsonDecode(posRaw) as Map<String, dynamic>;
    for (final entry in map.entries) {
      final ms = entry.value;
      if (ms is! num || ms <= 0) continue;
      await db.into(db.playbackPositionsTable).insertOnConflictUpdate(
            PlaybackPositionsTableCompanion.insert(
              audioUrl: entry.key,
              positionMs: ms.toInt(),
            ),
          );
    }
  }

  await prefs.setBool(_migratedFlag, true);
}
