import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/backup_service.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/data_reset_service.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/database/app_database.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/database/database_provider.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/export_service.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/id_gen.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/import_service.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/notes/providers/notes_provider.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/tasks/data/tasks_repository.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/tasks/models/repeat_rule.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/tasks/models/task_item.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/tasks/providers/tasks_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

AppDatabase memoryDb() => AppDatabase.withExecutor(NativeDatabase.memory());

/// Şema v1 (priority/repeatRule/tags yok) ile önceden doldurulmuş veritabanı.
void _createV1(dynamic raw) {
  raw.execute('''
    CREATE TABLE projects (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
      color_index INTEGER NOT NULL, sort_order INTEGER NOT NULL);
    CREATE TABLE tasks (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL,
      done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)), due_date INTEGER NULL,
      project_id TEXT NULL, sort_order INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '');
    CREATE TABLE subtasks (id TEXT NOT NULL PRIMARY KEY,
      task_id TEXT NOT NULL REFERENCES tasks (id) ON DELETE CASCADE, title TEXT NOT NULL,
      done INTEGER NOT NULL DEFAULT 0 CHECK (done IN (0, 1)), sort_order INTEGER NOT NULL);
    CREATE TABLE quick_notes (id TEXT NOT NULL PRIMARY KEY, body TEXT NOT NULL,
      updated_at INTEGER NOT NULL);
    INSERT INTO projects VALUES ('p1', 'İş', 2, 0);
    INSERT INTO tasks VALUES ('1700000000000', 'Rapor yaz', 0, 1700000000, 'p1', 0, 'önemli');
    INSERT INTO subtasks VALUES ('s1', '1700000000000', 'Taslak', 1, 0);
    INSERT INTO quick_notes VALUES ('n1', 'Eski not', 1700000000);
    PRAGMA user_version = 1;
  ''');
}

void main() {
  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('tr_TR');
  });

  group('şema geçişi', () {
    test('v1 → v2 geçişi notları, görevleri ve alt görevleri korur', () async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory(setup: _createV1));
      final notes = await db.select(db.quickNotes).get();
      expect(notes.single.body, 'Eski not');

      final tasks = await TasksRepository(db).loadAll();
      expect(tasks.single.title, 'Rapor yaz');
      expect(tasks.single.note, 'önemli');
      expect(tasks.single.projectId, 'p1');
      expect(tasks.single.subtasks.single.title, 'Taslak');
      expect(tasks.single.priority, TaskPriority.none);
      expect(tasks.single.repeat, RepeatRule.none);

      // Yeni tablolar kullanılabilir.
      final inserted = await TasksRepository(db).insert(title: 'Yeni', priority: tasks.single.priority);
      expect(inserted.id, isNotEmpty);
      await db.close();
    });

    test('dosyadaki veri kapatıp yeniden açınca kalır', () async {
      final dir = await Directory.systemTemp.createTemp('akilli_liste_db');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}not_gorev.sqlite');

      var db = AppDatabase.withExecutor(NativeDatabase(file));
      final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      await c.read(quickNotesProvider.future);
      await c.read(quickNotesProvider.notifier).add('Kalıcı not');
      c.dispose();
      await db.close();

      db = AppDatabase.withExecutor(NativeDatabase(file));
      expect((await db.select(db.quickNotes).get()).single.body, 'Kalıcı not');
      await db.close();
    });
  });

  group('notlar', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() async {
      db = memoryDb();
      c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      await c.read(quickNotesProvider.future);
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    Future<List<String>> stored() async =>
        (await db.select(db.quickNotes).get()).map((r) => r.body).toList();

    test('ekle, düzenle, sil ve geri al veritabanına yansır', () async {
      final n = c.read(quickNotesProvider.notifier);
      await n.add('  İlk not  ');
      await n.add('');
      expect(await stored(), ['İlk not']);

      final id = c.read(quickNotesProvider).value!.single.id;
      await n.edit(id, 'Düzenlenmiş not');
      expect(await stored(), ['Düzenlenmiş not']);
      await n.edit(id, '   ');
      expect(await stored(), ['Düzenlenmiş not'], reason: 'boş düzenleme notu silmemeli');

      final removed = await n.remove(id);
      expect(await stored(), isEmpty);
      await n.restore(removed!);
      expect(await stored(), ['Düzenlenmiş not']);
      expect(c.read(quickNotesProvider).value!.single.id, id);
    });

    test('art arda hızlı eklemede kimlik çakışmaz', () async {
      final n = c.read(quickNotesProvider.notifier);
      for (var i = 0; i < 20; i++) {
        await n.add('not $i');
      }
      expect((await stored()).length, 20);
    });

    test('not araması Türkçe harf duyarsız', () async {
      final n = c.read(quickNotesProvider.notifier);
      await n.add('İSTANBUL toplantısı');
      await n.add('Market listesi');
      final all = c.read(quickNotesProvider).value!;
      expect(filterNotes(all, 'istanbul').single.text, 'İSTANBUL toplantısı');
      expect(filterNotes(all, 'LİSTE').single.text, 'Market listesi');
      expect(filterNotes(all, '').length, 2);
    });
  });

  group('görevler', () {
    late AppDatabase db;
    late ProviderContainer c;

    setUp(() async {
      db = memoryDb();
      c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      await c.read(tasksProvider.future);
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('hızlı ekleme etiketleri kaydeder, silme alt görevleri de siler', () async {
      final n = c.read(tasksProvider.notifier);
      await n.add('#iş Rapor yaz');
      await n.add('İkinci');
      final first = c.read(tasksProvider).value!.first;
      expect(first.title, 'Rapor yaz');
      expect(first.tags.single.name, '#iş');
      await n.addSubtask(first.id, 'Taslak');

      await n.remove(first.id);
      expect((await db.select(db.tasks).get()).single.title, 'İkinci');
      expect(await db.select(db.subtasks).get(), isEmpty);
      expect(await db.select(db.taskTags).get(), isEmpty);
    });

    test('tekrarlayan görev tamamlanınca sonraki kopya eklenir', () async {
      final repo = c.read(tasksRepositoryProvider);
      final t = await repo.insert(
        title: 'Spor',
        dueDate: DateTime(2026, 1, 1),
        repeat: RepeatRule.daily,
      );
      await c.read(tasksProvider.notifier).reload();
      await c.read(tasksProvider.notifier).toggle(t.id);
      final all = await repo.loadAll();
      expect(all.length, 2);
      expect(all.firstWhere((x) => x.id == t.id).done, isTrue);
      final next = all.firstWhere((x) => x.id != t.id);
      expect(next.done, isFalse);
      expect(next.dueDate, DateTime(2026, 1, 2));
    });
  });

  group('dışa / içe aktarma', () {
    late AppDatabase db;

    setUp(() async {
      db = memoryDb();
      final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
      await c.read(tasksProvider.future);
      await c.read(quickNotesProvider.future);
      await c.read(tasksProvider.notifier).add('#ev @market Süt al');
      final task = c.read(tasksProvider).value!.single;
      await c.read(tasksProvider.notifier).addSubtask(task.id, 'Laktozsuz');
      await c.read(quickNotesProvider.notifier).add('Not gövdesi\nikinci satır');
      c.dispose();
    });
    tearDown(() => db.close());

    test('dışa aktarılan JSON boş veritabanına aynen geri yüklenir', () async {
      final json = await ExportService(db).exportJson();
      final target = memoryDb();
      final r = await ImportService(target).importJson(json);
      expect([r.tasks, r.notes, r.tags], [1, 1, 2]);
      expect(await ExportService(target).exportJson(), isNot(isEmpty));

      final a = jsonDecode(json) as Map<String, dynamic>;
      final b = jsonDecode(await ExportService(target).exportJson()) as Map<String, dynamic>;
      for (final k in ['projects', 'tags', 'tasks', 'notes']) {
        expect(b[k], a[k], reason: k);
      }
      await target.close();
    });

    for (final bad in [
      '{}',
      '[]',
      'bozuk json',
      '{"version": 9, "tasks": []}',
      '{"version": 2, "tasks": "x"}',
      '{"version": 2, "tasks": [{"id": "1"}]}',
    ]) {
      test('geçersiz yedek mevcut veriyi silmez: $bad', () async {
        final before = await ExportService(db).exportJson();
        await expectLater(
          ImportService(db).importJson(bad),
          throwsA(isA<FormatException>()),
        );
        final after = await ExportService(db).exportJson();
        expect(_withoutStamp(after), _withoutStamp(before));
      });
    }

    test('tüm veriyi silme her tabloyu boşaltır', () async {
      await DataResetService(db).clearAll();
      expect(await db.select(db.tasks).get(), isEmpty);
      expect(await db.select(db.quickNotes).get(), isEmpty);
      expect(await db.select(db.tags).get(), isEmpty);
      expect(await db.select(db.subtasks).get(), isEmpty);
    });
  });

  group('yedek dosyaları', () {
    late AppDatabase db;
    late Directory base;
    late BackupService backups;

    setUp(() async {
      db = memoryDb();
      base = await Directory.systemTemp.createTemp('akilli_liste_yedek');
      backups = BackupService(db, baseDir: () async => base);
    });
    tearDown(() async {
      await db.close();
      await base.delete(recursive: true);
    });

    test('boş veritabanında günlük yedek alınmaz, veri varsa günde bir kez alınır', () async {
      final day = DateTime(2026, 3, 4, 9);
      expect(await backups.dailyBackupIfNeeded(now: day), isNull);

      await db.into(db.quickNotes).insert(
            QuickNotesCompanion.insert(id: 'n', body: 'yedeklenecek', updatedAt: day),
          );
      final f = await backups.dailyBackupIfNeeded(now: day);
      expect(f, isNotNull);
      expect(await backups.dailyBackupIfNeeded(now: day.add(const Duration(hours: 5))), isNull);
      expect(await backups.dailyBackupIfNeeded(now: day.add(const Duration(days: 1))), isNotNull);

      // Yedek geri yüklenebilir bir dışa aktarmadır.
      final restored = memoryDb();
      final r = await ImportService(restored).importJson(await f!.readAsString());
      expect(r.notes, 1);
      await restored.close();
    });

    test('yedekler en yeni başta listelenir, en fazla 20 tutulur', () async {
      final t0 = DateTime(2026, 1, 1);
      for (var i = 0; i < 23; i++) {
        await backups.writeBackup(now: t0.add(Duration(minutes: i)));
      }
      // Aynı saniyede ikinci yedek üzerine yazmaz.
      await backups.writeBackup(now: t0.add(const Duration(minutes: 22)));
      final list = await backups.listBackups();
      expect(list.length, BackupService.keepCount);
      expect(list.first.path, endsWith('-elle-2.json'));
      expect(list.last.path, contains('20260101-0004'));
      final leftovers = base
          .listSync(recursive: true)
          .where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });
  });

  test('newId monoton artan ve benzersiz', () {
    final ids = List.generate(500, (_) => newId());
    expect(ids.toSet().length, 500);
    final nums = ids.map(int.parse).toList();
    for (var i = 1; i < nums.length; i++) {
      expect(nums[i], greaterThan(nums[i - 1]));
    }
  });

  test('ayrıştırıcı: geçerli yedek kabul edilir', () {
    expect(ImportService.parseBackup('{"version":2,"notes":[]}')['version'], 2);
  });
}

String _withoutStamp(String json) {
  final m = jsonDecode(json) as Map<String, dynamic>..remove('exportedAt');
  return jsonEncode(m);
}
