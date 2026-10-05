import 'episode_chapter.dart';

class NowPlaying {
  const NowPlaying({
    required this.episodeTitle,
    required this.audioUrl,
    required this.podcastTitle,
    required this.feedId,
    this.duration,
    this.localPath,
    this.imageUrl,
    this.chapters = const [],
  });

  final String episodeTitle;
  final String audioUrl;
  final String podcastTitle;
  final String feedId;
  final Duration? duration;
  final String? localPath;
  final String? imageUrl;
  final List<EpisodeChapter> chapters;
}
