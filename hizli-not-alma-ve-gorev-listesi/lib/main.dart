import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/backup_service.dart';
import 'core/database/app_database.dart';
import 'core/database/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');

  final db = AppDatabase();
  try {
    await migrateLegacyPrefs(db);
  } catch (e) {
    // Bozuk eski kayıt uygulamanın açılmasını engellemesin; bayrak
    // yazılmadığı için bir sonraki açılışta yeniden denenir.
    debugPrint('Eski veri taşınamadı: $e');
  }
  try {
    await BackupService(db).dailyBackupIfNeeded();
  } catch (e) {
    debugPrint('Günlük yedek alınamadı: $e');
  }
  await db.close();

  runApp(const ProviderScope(child: MyApp()));
}
