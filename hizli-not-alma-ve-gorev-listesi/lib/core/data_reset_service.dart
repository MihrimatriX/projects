import 'database/app_database.dart';

class DataResetService {
  DataResetService(this._db);

  final AppDatabase _db;

  Future<void> clearAll() => _db.transaction(() async {
        await _db.delete(_db.taskTags).go();
        await _db.delete(_db.subtasks).go();
        await _db.delete(_db.tasks).go();
        await _db.delete(_db.tags).go();
        await _db.delete(_db.projects).go();
        await _db.delete(_db.quickNotes).go();
      });
}
