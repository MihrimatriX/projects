import '../../../core/player/playback_positions.dart';
import '../utils/rss_parser.dart';

enum EpisodeFilter {
  all('Tümü'),
  unlistened('Dinlenmedi'),
  downloaded('İndirildi');

  const EpisodeFilter(this.label);
  final String label;
}

bool isEpisodeUnlistened(PodcastEpisode ep, EpisodeProgress? progress) {
  if (progress?.completed == true) return false;
  if (progress?.position == null) return true;
  final dur = ep.duration;
  if (dur == null || dur.inSeconds == 0) return true;
  return progress!.position!.inMilliseconds < dur.inMilliseconds * 0.9;
}

List<PodcastEpisode> filterEpisodes({
  required List<PodcastEpisode> episodes,
  required EpisodeFilter filter,
  required Map<String, EpisodeProgress> progressMap,
  String query = '',
}) {
  final q = _fold(query.trim());
  return episodes.where((ep) {
    if (q.isNotEmpty &&
        !_fold('${ep.title}\n${ep.description ?? ''}').contains(q)) {
      return false;
    }
    final progress = progressMap[ep.audioUrl];
    switch (filter) {
      case EpisodeFilter.all:
        return true;
      case EpisodeFilter.unlistened:
        return isEpisodeUnlistened(ep, progress);
      case EpisodeFilter.downloaded:
        return ep.localPath != null;
    }
  }).toList();
}

/// Türkçe büyük/küçük harf ve i/ı/İ/I farkını yok sayan arama anahtarı.
String _fold(String s) => s
    .replaceAll('İ', 'i')
    .replaceAll('I', 'i')
    .toLowerCase()
    .replaceAll('ı', 'i');
