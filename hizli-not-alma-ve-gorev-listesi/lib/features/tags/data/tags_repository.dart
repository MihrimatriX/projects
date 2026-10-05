import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/id_gen.dart';
import '../models/tag_item.dart';

class TagsRepository {
  TagsRepository(this._db);

  final AppDatabase _db;

  Future<List<TagItem>> loadAll() async {
    final rows = await _db.select(_db.tags).get();
    return rows
        .map((r) => TagItem(id: r.id, name: r.name, colorIndex: r.colorIndex))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Map<String, List<String>>> taskTagIdsByTask() async {
    final links = await _db.select(_db.taskTags).get();
    final map = <String, List<String>>{};
    for (final l in links) {
      map.putIfAbsent(l.taskId, () => []).add(l.tagId);
    }
    return map;
  }

  Future<List<TagItem>> tagsForTask(String taskId) async {
    final query = _db.select(_db.tags).join([
      innerJoin(
        _db.taskTags,
        _db.taskTags.tagId.equalsExp(_db.tags.id),
      ),
    ])
      ..where(_db.taskTags.taskId.equals(taskId));
    final rows = await query.get();
    return rows
        .map((r) => TagItem(
              id: r.readTable(_db.tags).id,
              name: r.readTable(_db.tags).name,
              colorIndex: r.readTable(_db.tags).colorIndex,
            ))
        .toList();
  }

  Future<TagItem> ensureTag(String rawName) async {
    final name = _normalize(rawName);
    final existing = await (_db.select(_db.tags)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) {
      return TagItem(
        id: existing.id,
        name: existing.name,
        colorIndex: existing.colorIndex,
      );
    }
    final id = '${newId()}_$name';
    final colorIndex = name.hashCode.abs() % 6;
    await _db.into(_db.tags).insert(
          TagsCompanion.insert(id: id, name: name, colorIndex: Value(colorIndex)),
        );
    return TagItem(id: id, name: name, colorIndex: colorIndex);
  }

  Future<void> setTaskTags(String taskId, List<String> tagIds) async {
    await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(taskId))).go();
    for (final tagId in tagIds) {
      await _db.into(_db.taskTags).insert(
            TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
          );
    }
  }

  String _normalize(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.startsWith('@') || t.startsWith('#')) return t;
    return '#$t';
  }
}
