import '../../../core/player/now_playing.dart';
import '../models/podcast_feed.dart';
import 'rss_parser.dart';

NowPlaying episodeToNowPlaying(PodcastFeed feed, PodcastEpisode ep) {
  return NowPlaying(
    episodeTitle: ep.title,
    audioUrl: ep.audioUrl,
    podcastTitle: feed.title,
    feedId: feed.id,
    duration: ep.duration,
    localPath: ep.localPath,
    chapters: ep.chapters,
    imageUrl: feed.imageUrl,
  );
}
