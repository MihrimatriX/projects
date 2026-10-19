import 'dart:convert';

import 'package:flutter/services.dart';

import '../features/notes/data/notes_repository.dart';
import '../features/projects/data/projects_repository.dart';
import '../features/tags/data/tags_repository.dart';
import '../features/tasks/data/tasks_repository.dart';
import '../features/tasks/models/task_item.dart';
import 'database/app_database.dart';

class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  Future<String> exportJson() async {
    final tasks = await TasksRepository(_db).loadAll();
    final projects = await ProjectsRepository(_db).loadAll();
    final notes = await NotesRepository(_db).loadAll();
    final tags = await TagsRepository(_db).loadAll();

    final payload = {
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'projects': projects
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'colorIndex': p.colorIndex,
                'sortOrder': p.sortOrder,
              })
          .toList(),
      'tags': tags
          .map((t) => {
                'id': t.id,
                'name': t.name,
                'colorIndex': t.colorIndex,
              })
          .toList(),
      'tasks': tasks
          .map((t) => {
                'id': t.id,
                'title': t.title,
                'done': t.done,
                'dueDate': t.dueDate?.toIso8601String(),
                'projectId': t.projectId,
                'sortOrder': t.sortOrder,
                'note': t.note,
                'priority': t.priority.value,
                'repeat': t.repeat.storageKey,
                'tagIds': t.tags.map((x) => x.id).toList(),
                'subtasks': t.subtasks
                    .map((s) => {
                          'id': s.id,
                          'title': s.title,
                          'done': s.done,
                          'sortOrder': s.sortOrder,
                        })
                    .toList(),
              })
          .toList(),
      'notes': notes
          .map((n) => {
                'id': n.id,
                'text': n.text,
                'updatedAt': n.updatedAt.toIso8601String(),
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> copyToClipboard() async {
    final json = await exportJson();
    await Clipboard.setData(ClipboardData(text: json));
  }
}
