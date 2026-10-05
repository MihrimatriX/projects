import 'package:flutter_test/flutter_test.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/providers/episode_progress_provider.dart';

void main() {
  test('episodeProgressKey ayni url listesi icin stabil', () {
    expect(episodeProgressKey(['a', 'b']), episodeProgressKey(['a', 'b']));
    expect(episodeProgressKey(['a', 'b']), isNot(equals(episodeProgressKey(['b', 'a']))));
  });
}
