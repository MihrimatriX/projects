import 'package:drift/drift.dart';

import 'connection.dart' as db_connection;

part 'app_database.g.dart';

class Feeds extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get url => text()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Episodes extends Table {
  TextColumn get audioUrl => text()();
  TextColumn get feedId => text().references(Feeds, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get published => dateTime().nullable()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get fetchedAt => dateTime()();
  TextColumn get localPath => text().nullable()();
  TextColumn get chaptersJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {audioUrl};
}

class PlaybackPositionsTable extends Table {
  TextColumn get audioUrl => text()();
  IntColumn get positionMs => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {audioUrl};
}

class PlayQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get audioUrl => text()();
  TextColumn get episodeTitle => text()();
  TextColumn get podcastTitle => text()();
  TextColumn get feedId => text()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get chaptersJson => text().nullable()();
}

@DriftDatabase(tables: [Feeds, Episodes, PlaybackPositionsTable, PlayQueueTable])
class AppDatabase extends _$AppDatabase {
  /// [executor] testlerde bellek içi veritabanı vermek için.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? db_connection.openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(episodes, episodes.localPath);
            await m.addColumn(episodes, episodes.chaptersJson);
            await m.addColumn(playbackPositionsTable, playbackPositionsTable.completed);
            await m.createTable(playQueueTable);
          }
          if (from < 3) {
            await m.addColumn(feeds, feeds.imageUrl);
          }
        },
      );
}
