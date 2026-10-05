import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';

// Uygulama boyunca tek Drift bağlantısı; tüm repository'ler bunu paylaşır.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Eski SharedPreferences verisini tek seferlik SQLite'a taşır.
Future<void> migrateLegacyPrefs(AppDatabase db) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('migrated_sqlite_v1') == true) return;

  final tasksRaw = prefs.getString('tasks_v1');
  if (tasksRaw != null) {
    final list = jsonDecode(tasksRaw) as List<dynamic>;
    var order = 0;
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: m['id'] as String,
              title: m['title'] as String,
              done: Value(m['done'] as bool? ?? false),
              sortOrder: order++,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  final notesRaw = prefs.getString('quick_notes_v1');
  if (notesRaw != null) {
    for (final e in jsonDecode(notesRaw) as List<dynamic>) {
      final m = e as Map<String, dynamic>;
      await db.into(db.quickNotes).insert(
            QuickNotesCompanion.insert(
              id: m['id'] as String,
              body: m['text'] as String,
              updatedAt: DateTime.parse(m['updatedAt'] as String),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  await prefs.setBool('migrated_sqlite_v1', true);
}
