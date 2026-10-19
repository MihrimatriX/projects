import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database/app_database.dart';
import 'export_service.dart';

/// JSON yedek dosyaları (dışa aktarma ile aynı sürüm 2 şeması).
///
/// Yedekler veritabanının yanında, `Belgeler\Akilli Liste Yedekleri\`
/// altında tutulur. İçe aktarma ve "tüm veriyi sil" öncesinde otomatik
/// yedek alınır; uygulama açılışında da günde bir kez yedeklenir.
class BackupService {
  BackupService(this._db, {Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  static const folderName = 'Akilli Liste Yedekleri';
  static const filePrefix = 'akilli-liste-';
  static const keepCount = 20;

  final AppDatabase _db;
  final Future<Directory> Function() _baseDir;

  Future<Directory> backupDir() async =>
      Directory(p.join((await _baseDir()).path, folderName));

  /// Yedek dosyaları, en yeni başta.
  Future<List<File>> listBackups() async {
    final dir = await backupDir();
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) =>
            e is File &&
            p.basename(e.path).startsWith(filePrefix) &&
            e.path.toLowerCase().endsWith('.json'))
        .cast<File>()
        .toList();
    // Dosya adı zaman damgası içerdiği için ada göre sıralama kronolojiktir
    // (uzantısız karşılaştırma: aynı saniyedeki "-2" eki daha yeni sayılır).
    files.sort((a, b) => p.basenameWithoutExtension(b.path)
        .compareTo(p.basenameWithoutExtension(a.path)));
    return files;
  }

  /// Tüm veriyi `akilli-liste-<yyyyMMdd-HHmmss>-<etiket>.json` dosyasına yazar.
  Future<File> writeBackup({String label = 'elle', DateTime? now}) async {
    final dir = await backupDir();
    await dir.create(recursive: true);
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(now ?? DateTime.now());
    var file = File(p.join(dir.path, '$filePrefix$stamp-$label.json'));
    var n = 2;
    while (await file.exists()) {
      file = File(p.join(dir.path, '$filePrefix$stamp-$label-$n.json'));
      n++;
    }
    final json = await ExportService(_db).exportJson();
    // Önce geçici dosyaya yaz, sonra yeniden adlandır: yarım yedek kalmasın.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
    await _prune();
    return file;
  }

  /// Bugün henüz yedek yoksa bir "otomatik" yedek alır; boş veritabanında yedeklemez.
  Future<File?> dailyBackupIfNeeded({DateTime? now}) async {
    final today = DateFormat('yyyyMMdd').format(now ?? DateTime.now());
    final existing = await listBackups();
    if (existing.any((f) => p.basename(f.path).startsWith('$filePrefix$today'))) {
      return null;
    }
    final hasData = (await _db.select(_db.tasks).get()).isNotEmpty ||
        (await _db.select(_db.quickNotes).get()).isNotEmpty ||
        (await _db.select(_db.projects).get()).isNotEmpty;
    if (!hasData) return null;
    return writeBackup(label: 'otomatik', now: now);
  }

  Future<void> _prune() async {
    final files = await listBackups();
    for (final f in files.skip(keepCount)) {
      try {
        await f.delete();
      } on FileSystemException {
        // Kilitli dosya: bir sonraki yedeklemede tekrar denenir.
      }
    }
  }
}
