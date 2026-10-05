import 'package:flutter_test/flutter_test.dart';
import 'package:minimalist_podcast_uygulamasi/core/player/playback_positions.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/utils/episode_filter.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/utils/rss_parser.dart';

void main() {
  test('unlistened filter excludes completed', () {
    const ep = PodcastEpisode(title: 'A', audioUrl: 'http://a');
    final filtered = filterEpisodes(
      episodes: [ep],
      filter: EpisodeFilter.unlistened,
      progressMap: {
        'http://a': const EpisodeProgress(completed: true),
      },
    );
    expect(filtered, isEmpty);
  });

  test('downloaded filter keeps local episodes', () {
    const ep = PodcastEpisode(
      title: 'B',
      audioUrl: 'http://b',
      localPath: '/tmp/ep.mp3',
    );
    final filtered = filterEpisodes(
      episodes: [ep],
      filter: EpisodeFilter.downloaded,
      progressMap: {},
    );
    expect(filtered.length, 1);
  });

  test('arama başlık ve açıklamada, Türkçe harf duyarsız', () {
    const eps = [
      PodcastEpisode(title: 'İklim krizi', audioUrl: 'http://1'),
      PodcastEpisode(title: 'Teknoloji', audioUrl: 'http://2', description: 'Yapay ZEKÂ ve IŞIK'),
    ];
    List<String> q(String s) => filterEpisodes(
          episodes: eps,
          filter: EpisodeFilter.all,
          progressMap: {},
          query: s,
        ).map((e) => e.audioUrl).toList();
    expect(q('iklim'), ['http://1']);
    expect(q('ışık'), ['http://2']);
    expect(q(''), ['http://1', 'http://2']);
    expect(q('yok'), isEmpty);
  });
}