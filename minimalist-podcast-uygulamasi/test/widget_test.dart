import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minimalist_podcast_uygulamasi/app.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/models/podcast_feed.dart';
import 'package:minimalist_podcast_uygulamasi/features/feeds/providers/feeds_provider.dart';

class _EmptyFeeds extends FeedsNotifier {
  @override
  Future<List<PodcastFeed>> build() async => [];
}

void main() {
  testWidgets('bos feed durumunda baslik gorunur', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feedsProvider.overrideWith(_EmptyFeeds.new)],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Podcast dinlemeye başla'), findsOneWidget);
  });
}
