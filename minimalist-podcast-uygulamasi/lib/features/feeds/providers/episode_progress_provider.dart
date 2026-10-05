import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/player/playback_positions.dart';
import 'feeds_provider.dart';

/// ponytail: List family key identity equality yuzunden her build'de yeniden yukler — string key.
final episodeProgressProvider =
    FutureProvider.family<Map<String, EpisodeProgress>, String>((ref, urlsKey) async {
  if (urlsKey.isEmpty) return {};
  final urls = urlsKey.split('\x1f');
  return ref.read(playbackPositionsProvider).getProgressForUrls(urls);
});

String episodeProgressKey(Iterable<String> audioUrls) => audioUrls.join('\x1f');
