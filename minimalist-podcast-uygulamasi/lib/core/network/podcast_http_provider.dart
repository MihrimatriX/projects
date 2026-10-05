import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/app_settings.dart';
import 'podcast_http.dart';

final podcastHttpProvider = Provider<PodcastHttp>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  final custom = settings?.corsProxyBase?.trim();
  return PodcastHttp(
    corsProxyBase: (custom != null && custom.isNotEmpty) ? custom : null,
  );
});
