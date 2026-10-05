import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'legacy_migration.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final databaseReadyProvider = FutureProvider<void>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  await migrateLegacyPrefsIfNeeded(db);
});
