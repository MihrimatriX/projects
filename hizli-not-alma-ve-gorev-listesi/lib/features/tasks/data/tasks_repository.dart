import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/id_gen.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/models/tag_item.dart';
import '../models/repeat_rule.dart';
import '../models/subtask_item.dart';
import '../models/task_item.dart';

class TasksRepository {
  TasksRepository(this._db, [TagsRepository? tagsRepo])
      : _tagsRepo = tagsRepo ?? TagsRepository(_db);

  final AppDatabase _db;
  final TagsRepository _tagsRepo;

  Future<List<TaskItem>> loadAll() async {
    final taskRows = await (_db.select(_db.tasks)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    final subRows = await _db.select(_db.subtasks).get();
    final tagLinks = await _tagsRepo.taskTagIdsByTask();
    final allTags = {for (final t in await _tagsRepo.loadAll()) t.id: t};

    final subsByTask = <String, List<SubtaskItem>>{};
    for (final s in subRows) {
      subsByTask.putIfAbsent(s.taskId, () => []).add(
            SubtaskItem(
              id: s.id,
              taskId: s.taskId,
              title: s.title,
              done: s.done,
              sortOrder: s.sortOrder,
            ),
          );
    }
    for (final list in subsByTask.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return taskRows.map((r) {
      final tagIds = tagLinks[r.id] ?? [];
      final tags = tagIds
          .map((id) => allTags[id])
          .whereType<TagItem>()
          .toList();
      return TaskItem(
        id: r.id,
        title: r.title,
        done: r.done,
        dueDate: r.dueDate,
        projectId: r.projectId,
        sortOrder: r.sortOrder,
        note: r.note,
        subtasks: subsByTask[r.id] ?? const [],
        tags: tags,
        priority: TaskPriorityExt.fromValue(r.priority),
        repeat: RepeatRule.fromStorage(r.repeatRule),
        createdAt: DateTime.fromMillisecondsSinceEpoch(int.tryParse(r.id) ?? 0),
      );
    }).toList();
  }

  Future<TaskItem> insert({
    required String title,
    String? projectId,
    DateTime? dueDate,
    List<String> tagIds = const [],
    TaskPriority priority = TaskPriority.none,
    RepeatRule repeat = RepeatRule.none,
  }) async {
    final id = newId();
    final count = await _db.select(_db.tasks).get();
    await _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            id: id,
            title: title,
            projectId: Value(projectId),
            dueDate: Value(dueDate),
            sortOrder: count.length,
            priority: Value(priority.value),
            repeatRule: Value(repeat.storageKey),
          ),
        );
    await _tagsRepo.setTaskTags(id, tagIds);
    final tags = (await _tagsRepo.loadAll()).where((t) => tagIds.contains(t.id)).toList();
    return TaskItem(
      id: id,
      title: title,
      projectId: projectId,
      dueDate: dueDate,
      sortOrder: count.length,
      tags: tags,
      priority: priority,
      repeat: repeat,
    );
  }

  Future<void> update(TaskItem task) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(
        title: Value(task.title),
        done: Value(task.done),
        dueDate: Value(task.dueDate),
        projectId: Value(task.projectId),
        sortOrder: Value(task.sortOrder),
        note: Value(task.note),
        priority: Value(task.priority.value),
        repeatRule: Value(task.repeat.storageKey),
      ),
    );
    await _tagsRepo.setTaskTags(task.id, task.tags.map((t) => t.id).toList());
  }

  Future<void> delete(String id) async {
    // SQLite'ta foreign_keys PRAGMA'sı açık değil; cascade çalışmadığı için
    // alt görev ve etiket bağları elle silinir.
    await (_db.delete(_db.subtasks)..where((t) => t.taskId.equals(id))).go();
    await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(id))).go();
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorder(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(orderedIds[i])))
          .write(TasksCompanion(sortOrder: Value(i)));
    }
  }

  Future<SubtaskItem> addSubtask(String taskId, String title) async {
    final id = '${newId()}_sub';
    final existing = await (_db.select(_db.subtasks)
          ..where((t) => t.taskId.equals(taskId)))
        .get();
    await _db.into(_db.subtasks).insert(
          SubtasksCompanion.insert(
            id: id,
            taskId: taskId,
            title: title,
            sortOrder: existing.length,
          ),
        );
    return SubtaskItem(id: id, taskId: taskId, title: title, sortOrder: existing.length);
  }

  Future<void> updateSubtask(SubtaskItem sub) async {
    await (_db.update(_db.subtasks)..where((t) => t.id.equals(sub.id))).write(
      SubtasksCompanion(
        title: Value(sub.title),
        done: Value(sub.done),
        sortOrder: Value(sub.sortOrder),
      ),
    );
  }

  Future<void> deleteSubtask(String id) async {
    await (_db.delete(_db.subtasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.taskTags).go();
    await _db.delete(_db.subtasks).go();
    await _db.delete(_db.tasks).go();
  }
}
