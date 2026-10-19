import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  IntColumn get colorArgb => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class TimeEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();
}

@DriftDatabase(tables: [Projects, TimeEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.test() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(projects, projects.colorArgb);
          }
        },
        // SQLite yabancı anahtarları varsayılan olarak kapalıdır; açılmazsa proje
        // silinince `onDelete: cascade` çalışmaz ve kayıtlar sahipsiz kalır.
        beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'time_tracking.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  Future<List<Project>> getAllProjects() => select(projects).get();

  Future<int> insertProject(String name, {int colorArgb = 0}) =>
      into(projects).insert(ProjectsCompanion.insert(name: name, colorArgb: Value(colorArgb)));

  Future<void> updateProject(int id, {String? name, int? colorArgb}) {
    return (update(projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        colorArgb: colorArgb != null ? Value(colorArgb) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteProject(int id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  Future<int> startEntry(int projectId, {String note = ''}) => into(timeEntries).insert(
        TimeEntriesCompanion.insert(
          projectId: projectId,
          startedAt: DateTime.now(),
          note: Value(note),
        ),
      );

  Future<void> stopEntry(int entryId, {DateTime? endedAt}) async {
    await (update(timeEntries)..where((t) => t.id.equals(entryId))).write(
      TimeEntriesCompanion(endedAt: Value(endedAt ?? DateTime.now())),
    );
  }

  Future<void> deleteEntry(int entryId) =>
      (delete(timeEntries)..where((t) => t.id.equals(entryId))).go();

  Future<TimeEntry?> getActiveEntry() {
    // limit(1): hızlı çift "Başlat" iki açık kayıt üretirse getSingleOrNull istisna fırlatırdı.
    return (select(timeEntries)
          ..where((t) => t.endedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  static DateTime _dayStart(DateTime day) => DateTime(day.year, day.month, day.day);

  Future<List<TimeEntry>> getEntriesForDay(DateTime day, {bool includeActive = false}) {
    final start = _dayStart(day);
    // Takvim günü: yaz saati geçişinde gün 23/25 saat olabilir.
    final end = DateTime(start.year, start.month, start.day + 1);
    return (select(timeEntries)
          ..where((t) {
            final inDay =
                t.startedAt.isBiggerOrEqualValue(start) & t.startedAt.isSmallerThanValue(end);
            return includeActive ? inDay : inDay & t.endedAt.isNotNull();
          })
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  Future<List<TimeEntry>> getTodayEntries({bool includeActive = false}) =>
      getEntriesForDay(DateTime.now(), includeActive: includeActive);

  Future<Duration> dayTotal(DateTime day, {Duration? runningExtra}) async {
    final entries = await getEntriesForDay(day, includeActive: true);
    var total = Duration.zero;
    final now = DateTime.now();
    for (final e in entries) {
      if (e.endedAt != null) {
        total += e.endedAt!.difference(e.startedAt);
      } else if (runningExtra != null && _dayStart(e.startedAt) == _dayStart(day)) {
        total += runningExtra;
      } else if (e.endedAt == null && _dayStart(e.startedAt) == _dayStart(day)) {
        total += now.difference(e.startedAt);
      }
    }
    return total;
  }

  Future<Duration> getTodayTotal({Duration? runningExtra}) =>
      dayTotal(DateTime.now(), runningExtra: runningExtra);

  Future<Map<int, Duration>> dayByProject(DateTime day, {Duration? runningExtra, int? runningProjectId}) async {
    final entries = await getEntriesForDay(day, includeActive: true);
    final map = <int, Duration>{};
    final now = DateTime.now();
    for (final e in entries) {
      Duration d;
      if (e.endedAt != null) {
        d = e.endedAt!.difference(e.startedAt);
      } else if (runningExtra != null && e.id == entries.where((x) => x.endedAt == null).firstOrNull?.id) {
        d = runningExtra;
      } else if (e.endedAt == null) {
        d = now.difference(e.startedAt);
      } else {
        continue;
      }
      map[e.projectId] = (map[e.projectId] ?? Duration.zero) + d;
    }
    if (runningProjectId != null && runningExtra != null && entries.every((e) => e.endedAt != null)) {
      map[runningProjectId] = (map[runningProjectId] ?? Duration.zero) + runningExtra;
    }
    return map;
  }

  Future<Map<int, Duration>> getTodayByProject({Duration? runningExtra, int? runningProjectId}) =>
      dayByProject(DateTime.now(), runningExtra: runningExtra, runningProjectId: runningProjectId);

  Future<List<TimeEntry>> getEntriesBetween(DateTime start, DateTime end) {
    return (select(timeEntries)
          ..where(
            (t) =>
                t.startedAt.isBiggerOrEqualValue(start) &
                t.startedAt.isSmallerThanValue(end) &
                t.endedAt.isNotNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  Future<List<TimeEntry>> getDayEntriesForExport(DateTime day) {
    final start = _dayStart(day);
    return getEntriesBetween(start, DateTime(start.year, start.month, start.day + 1));
  }
}
