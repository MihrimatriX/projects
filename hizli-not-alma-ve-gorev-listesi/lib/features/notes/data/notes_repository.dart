import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../models/note_item.dart';

class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;

  Future<List<NoteItem>> loadAll() async {
    final rows = await (_db.select(_db.quickNotes)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
    return rows
        .map((r) => NoteItem(id: r.id, text: r.body, updatedAt: r.updatedAt))
        .toList();
  }

  /// Yeni not ekler; geri alınan silmede aynı kimlikle yeniden yazar.
  Future<void> insert(NoteItem note) async {
    await _db.into(_db.quickNotes).insert(
          QuickNotesCompanion.insert(
            id: note.id,
            body: note.text,
            updatedAt: note.updatedAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> update(NoteItem note) async {
    await (_db.update(_db.quickNotes)..where((t) => t.id.equals(note.id))).write(
      QuickNotesCompanion(
        body: Value(note.text),
        updatedAt: Value(note.updatedAt),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.quickNotes)..where((t) => t.id.equals(id))).go();
  }
}
