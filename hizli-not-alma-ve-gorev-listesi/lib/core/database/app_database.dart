import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get projectId => text().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get note => text().withDefault(const Constant(''))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get repeatRule => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId => text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

class QuickNotes extends Table {
  TextColumn get id => text()();
  TextColumn get body => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Projects, Tasks, Subtasks, Tags, TaskTags, QuickNotes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Testler (ör. `NativeDatabase.memory()`) ve geçiş denemeleri için.
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(tasks, tasks.priority);
            await m.addColumn(tasks, tasks.repeatRule);
            await m.createTable(tags);
            await m.createTable(taskTags);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'not_gorev.sqlite'));
    return NativeDatabase(file);
  });
}
