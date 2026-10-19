import 'dart:convert';

import 'package:drift/drift.dart';

import 'database/app_database.dart';

class ImportResult {
  const ImportResult({
    required this.projects,
    required this.tasks,
    required this.notes,
    required this.tags,
  });

  final int projects;
  final int tasks;
  final int notes;
  final int tags;
}

class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  // Tek transaction: JSON yarıda hatalı çıkarsa silinen veri geri alınır.
  Future<ImportResult> importJson(String raw, {bool merge = false}) async {
    try {
      return await _db.transaction(() => _importJson(raw, merge: merge));
    } on TypeError {
      // Eksik/yanlış tipte alan: transaction geri alındı, veri değişmedi.
      throw const FormatException('Yedekte eksik ya da hatalı alanlı kayıt var; hiçbir veri değiştirilmedi.');
    }
  }

  /// Yedek biçimini veri silinmeden ÖNCE doğrular. Önceden `{}` gibi geçerli
  /// ama alakasız bir JSON, mevcut tüm veriyi silip hiçbir şey eklemiyordu.
  static Map<String, dynamic> parseBackup(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Geçerli bir JSON değil.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Akıllı Liste yedeği değil (JSON nesnesi bekleniyordu).');
    }
    final version = decoded['version'];
    if (version is! int || version < 1 || version > 2) {
      throw FormatException(
        'Desteklenmeyen yedek sürümü: ${version ?? 'yok'} (beklenen: 2).',
      );
    }
    const keys = ['projects', 'tags', 'tasks', 'notes'];
    if (!keys.any(decoded.containsKey)) {
      throw const FormatException('Yedekte görev, proje, etiket veya not listesi yok.');
    }
    for (final k in keys) {
      final v = decoded[k];
      if (v != null && v is! List) {
        throw FormatException('"$k" alanı liste olmalı.');
      }
    }
    return decoded;
  }

  Future<ImportResult> _importJson(String raw, {bool merge = false}) async {
    final data = parseBackup(raw);
    if (!merge) {
      await _db.delete(_db.taskTags).go();
      await _db.delete(_db.subtasks).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.projects).go();
      await _db.delete(_db.quickNotes).go();
    }

    var tagCount = 0;
    var projectCount = 0;
    var taskCount = 0;
    var noteCount = 0;

    final tags = data['tags'] as List<dynamic>? ?? [];
    for (final e in tags) {
      final m = e as Map<String, dynamic>;
      await _db.into(_db.tags).insert(
            TagsCompanion.insert(
              id: m['id'] as String,
              name: m['name'] as String,
              colorIndex: Value(m['colorIndex'] as int? ?? 0),
            ),
            mode: InsertMode.insertOrReplace,
          );
      tagCount++;
    }

    final projects = data['projects'] as List<dynamic>? ?? [];
    for (final e in projects) {
      final m = e as Map<String, dynamic>;
      await _db.into(_db.projects).insert(
            ProjectsCompanion.insert(
              id: m['id'] as String,
              name: m['name'] as String,
              colorIndex: m['colorIndex'] as int,
              sortOrder: m['sortOrder'] as int,
            ),
            mode: InsertMode.insertOrReplace,
          );
      projectCount++;
    }

    final tasks = data['tasks'] as List<dynamic>? ?? [];
    for (final e in tasks) {
      final m = e as Map<String, dynamic>;
      final id = m['id'] as String;
      await _db.into(_db.tasks).insert(
            TasksCompanion.insert(
              id: id,
              title: m['title'] as String,
              done: Value(m['done'] as bool? ?? false),
              dueDate: Value(_parseDate(m['dueDate'])),
              projectId: Value(m['projectId'] as String?),
              sortOrder: m['sortOrder'] as int? ?? 0,
              note: Value(m['note'] as String? ?? ''),
              priority: Value(m['priority'] as int? ?? 0),
              repeatRule: Value(m['repeat'] as String?),
            ),
            mode: InsertMode.insertOrReplace,
          );
      taskCount++;

      final tagIds = (m['tagIds'] as List<dynamic>?)?.cast<String>() ?? [];
      for (final tagId in tagIds) {
        await _db.into(_db.taskTags).insert(
              TaskTagsCompanion.insert(taskId: id, tagId: tagId),
              mode: InsertMode.insertOrIgnore,
            );
      }

      final subs = m['subtasks'] as List<dynamic>? ?? [];
      for (final s in subs) {
        final sm = s as Map<String, dynamic>;
        await _db.into(_db.subtasks).insert(
              SubtasksCompanion.insert(
                id: sm['id'] as String,
                taskId: id,
                title: sm['title'] as String,
                done: Value(sm['done'] as bool? ?? false),
                sortOrder: sm['sortOrder'] as int? ?? 0,
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    }

    final notes = data['notes'] as List<dynamic>? ?? [];
    for (final e in notes) {
      final m = e as Map<String, dynamic>;
      await _db.into(_db.quickNotes).insert(
            QuickNotesCompanion.insert(
              id: m['id'] as String,
              body: m['text'] as String,
              updatedAt: DateTime.parse(m['updatedAt'] as String),
            ),
            mode: InsertMode.insertOrReplace,
          );
      noteCount++;
    }

    return ImportResult(
      projects: projectCount,
      tasks: taskCount,
      notes: noteCount,
      tags: tagCount,
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.parse(v as String);
  }
}
