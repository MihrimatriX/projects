import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/settings/app_settings.dart';
import 'download_service.dart';

final downloadServiceProvider = Provider(
  (ref) => DownloadService(
    ref.watch(appDatabaseProvider),
    ref.watch(appSettingsServiceProvider),
  ),
);

final downloadProgressProvider = StateProvider<Map<String, double>>((ref) => {});
