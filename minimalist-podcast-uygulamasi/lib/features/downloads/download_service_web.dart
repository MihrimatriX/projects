import 'package:drift/drift.dart';

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
  // ignore: unused_field — API parity with native implementation
  final AppSettings _settings;

  double? progressFor(String audioUrl) => null;

  Future<String?> downloadEpisode({
    required String feedId,
    required String audioUrl,
    void Function(double fraction)? onProgress,
  }) async {
    throw Exception(
      'Web sürümünde offline indirme yok. Bölümler doğrudan akış (stream) ile oynatılır.',
    );
  }

  Future<void> deleteDownload(String audioUrl) async {
    await (_db.update(_db.episodes)..where((t) => t.audioUrl.equals(audioUrl))).write(
          const EpisodesCompanion(localPath: Value(null)),
        );
  }

  Future<String?> localPathFor(String audioUrl) async => null;
}
