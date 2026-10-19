import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/app_database.dart';
import '../../core/settings/app_settings.dart';

class DownloadProgress {
  const DownloadProgress({required this.audioUrl, required this.fraction});

  final String audioUrl;
  final double fraction;
}

class DownloadService {
  DownloadService(this._db, this._settings);

  final AppDatabase _db;
  final AppSettings _settings;

  final _progress = <String, double>{};

  double? progressFor(String audioUrl) => _progress[audioUrl];

  Future<bool> _canDownload() async {
    if (!await _settings.getWifiOnlyDownloads()) return true;
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ||
        result.contains(ConnectivityResult.ethernet);
  }

  Future<String?> downloadEpisode({
    required String feedId,
    required String audioUrl,
    void Function(double fraction)? onProgress,
  }) async {
    if (!await _canDownload()) {
      throw Exception('İndirme yalnızca Wi-Fi ile açık. Ayarlardan değiştirebilirsiniz.');
    }

    final existing = await (_db.select(_db.episodes)
          ..where((t) => t.audioUrl.equals(audioUrl)))
        .getSingleOrNull();
    if (existing?.localPath != null) {
      final f = File(existing!.localPath!);
      if (f.existsSync()) return existing.localPath;
    }

    final uri = Uri.tryParse(audioUrl);
    if (uri == null) throw const FormatException('Geçersiz ses URL');

    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'downloads', feedId));
    await folder.create(recursive: true);
    final ext = p.extension(uri.path);
    final safeExt = ext.isNotEmpty && ext.length <= 5 ? ext : '.mp3';
    final file = File(p.join(folder.path, '${audioUrl.hashCode}$safeExt'));

    final request = http.Request('GET', uri);
    request.headers['User-Agent'] = 'MinimalPodcast/1.0';
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('İndirilemedi: ${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = file.openWrite();
    _progress[audioUrl] = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        _progress[audioUrl] = received / total;
        onProgress?.call(_progress[audioUrl]!);
      }
    }
    await sink.close();
    _progress.remove(audioUrl);

    await (_db.update(_db.episodes)..where((t) => t.audioUrl.equals(audioUrl))).write(
          EpisodesCompanion(localPath: Value(file.path)),
        );

    return file.path;
  }

  Future<void> deleteDownload(String audioUrl) async {
    final row = await (_db.select(_db.episodes)
          ..where((t) => t.audioUrl.equals(audioUrl)))
        .getSingleOrNull();
    if (row?.localPath != null) {
      final f = File(row!.localPath!);
      if (f.existsSync()) await f.delete();
    }
    await (_db.update(_db.episodes)..where((t) => t.audioUrl.equals(audioUrl))).write(
          const EpisodesCompanion(localPath: Value(null)),
        );
  }

  Future<String?> localPathFor(String audioUrl) async {
    final row = await (_db.select(_db.episodes)
          ..where((t) => t.audioUrl.equals(audioUrl)))
        .getSingleOrNull();
    if (row?.localPath == null) return null;
    final f = File(row!.localPath!);
    return f.existsSync() ? row.localPath : null;
  }
}
