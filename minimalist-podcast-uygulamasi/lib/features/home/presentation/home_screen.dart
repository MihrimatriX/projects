import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/podcast_http_provider.dart';
import '../../../core/platform/platform_info.dart';
import '../../../core/player/player_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../downloads/downloads_provider.dart';
import '../../feeds/models/podcast_feed.dart';
import '../../feeds/providers/continue_listening_provider.dart';
import '../../feeds/providers/episode_progress_provider.dart';
import '../../feeds/providers/episodes_provider.dart';
import '../../feeds/providers/feeds_provider.dart';
import '../../feeds/services/feed_refresh_service.dart';
import '../../feeds/utils/episode_filter.dart';
import '../../feeds/utils/episode_playback.dart';
import '../../feeds/utils/rss_parser.dart';
import '../../feeds/widgets/podcast_cover.dart';
import '../../podcast/widgets/add_podcast_dialog.dart';
import '../../podcast/widgets/episode_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialFilter = EpisodeFilter.all});

  final EpisodeFilter initialFilter;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  PodcastFeed? _selected;
  late EpisodeFilter _filter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  Future<void> _importOpml() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('OPML içe aktar'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'OPML dosyasının içeriğini yapıştır'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('İçe aktar')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      controller.dispose();
      return;
    }
    try {
      final count = await ref.read(feedsProvider.notifier).importOpml(controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(count > 0 ? '$count podcast eklendi' : 'Yeni podcast yok')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İçe aktarılamadı: $e')),
        );
      }
    }
    controller.dispose();
  }

  void _showEpisodeMenu(PodcastFeed feed, PodcastEpisode ep) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Dinle'),
              onTap: () async {
                Navigator.pop(ctx);
                await _togglePlay(feed, ep, false, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Sıraya ekle'),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(playerProvider.notifier).addToQueue(
                      episodeToNowPlaying(feed, ep),
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sıraya eklendi')),
                  );
                }
              },
            ),
            if (PlatformInfo.supportsOfflineDownload) ...[
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('İndir'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _download(feed, ep);
                },
              ),
              if (ep.localPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('İndirmeyi sil'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(downloadServiceProvider).deleteDownload(ep.audioUrl);
                    ref.invalidate(episodesProvider(feed));
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _download(PodcastFeed feed, PodcastEpisode ep) async {
    try {
      await ref.read(downloadServiceProvider).downloadEpisode(
            feedId: feed.id,
            audioUrl: ep.audioUrl,
            onProgress: (f) {
              ref.read(downloadProgressProvider.notifier).update(
                    (m) => {...m, ep.audioUrl: f},
                  );
            },
          );
      ref.invalidate(episodesProvider(feed));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirildi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      ref.read(downloadProgressProvider.notifier).update((m) {
        final next = Map<String, double>.from(m);
        next.remove(ep.audioUrl);
        return next;
      });
    }
  }

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Çevrimdışıyken zorla yenileme hata verir; önbellekteki bölümler yerinde kalır.
  Future<void> _refreshFeed(PodcastFeed feed) async {
    try {
      await ref.read(episodesRepositoryProvider).getEpisodes(
            feedId: feed.id,
            feedUrl: feed.url,
            http: ref.read(podcastHttpProvider),
            forceRefresh: true,
          );
      ref.invalidate(episodesProvider(feed));
      _snack('Bölümler güncellendi');
    } catch (e) {
      _snack('Yenilenemedi: $e');
    }
  }

  Future<void> _unsubscribe(PodcastFeed feed) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text('Abonelikten çık'),
        content: Text('"${feed.title}" kütüphaneden kaldırılsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaldır')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(feedsProvider.notifier).remove(feed.id);
    if (mounted) setState(() => _selected = null);
    _snack('"${feed.title}" kaldırıldı');
  }

  Future<void> _togglePlay(PodcastFeed feed, PodcastEpisode ep, bool playing, bool isCurrent) async {
    final player = ref.read(playerProvider.notifier).player;
    if (isCurrent && playing) {
      await player.pause();
      return;
    }
    if (isCurrent) {
      await player.play();
      return;
    }
    try {
      await ref.read(playerProvider.notifier).playEpisode(
            episodeTitle: ep.title,
            audioUrl: ep.audioUrl,
            podcastTitle: feed.title,
            feedId: feed.id,
            duration: ep.duration,
            localPath: ep.localPath,
            chapters: ep.chapters,
            imageUrl: feed.imageUrl,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oynatılamadı: $e')),
        );
      }
    }
  }

  Widget _feedTile(PodcastFeed feed, bool selected, {required bool compact}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selected = feed),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: compact ? 12 : 10,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.bgPlaying : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              PodcastCover(imageUrl: feed.imageUrl, size: compact ? 56 : 40),
              SizedBox(width: compact ? 16 : 12),
              Expanded(
                child: Text(
                  feed.title,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 16 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebar(List<PodcastFeed> feeds) {
    return Container(
      width: AppLayout.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'PODCASTLERİM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08,
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: feeds.length,
              itemBuilder: (_, i) => _feedTile(feeds[i], feeds[i].id == _selected?.id, compact: false),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => showAddPodcastDialog(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Podcast ekle'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueSection() {
    final continueAsync = ref.watch(continueListeningProvider);
    return continueAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty || _filter != EpisodeFilter.all) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'DEVAM ET',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.08,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final playerState = ref.watch(playerProvider);
              final isCurrent = playerState.nowPlaying?.audioUrl == e.episode.audioUrl;
              final player = ref.read(playerProvider.notifier).player;
              return StreamBuilder(
                stream: player.playerStateStream,
                builder: (context, snap) {
                  final playing = isCurrent && (snap.data?.playing ?? false);
                  return EpisodeRow(
                    episode: e.episode,
                    progress: e.progress,
                    playing: playing,
                    isCurrent: isCurrent,
                    onTap: () => _togglePlay(e.feed, e.episode, playing, isCurrent),
                    onPlay: () => _togglePlay(e.feed, e.episode, playing, isCurrent),
                    onMenu: () => _showEpisodeMenu(e.feed, e.episode),
                  );
                },
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _episodesPanel(PodcastFeed feed, {bool showHeader = true}) {
    final episodesAsync = ref.watch(episodesProvider(feed));
    final playerState = ref.watch(playerProvider);
    final currentUrl = playerState.nowPlaying?.audioUrl;
    final player = ref.read(playerProvider.notifier).player;
    final downloadProgress = ref.watch(downloadProgressProvider);

    return episodesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                'Bölümler yüklenemedi',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                PlatformInfo.isWeb && e is! FeedException
                    ? 'İnternet bağlantını ve Ayarlar → Gelişmiş bölümünü kontrol et.'
                    : '$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(episodesProvider(feed)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yeniden dene'),
              ),
            ],
          ),
        ),
      ),
      data: (allEpisodes) {
        final urlsKey = episodeProgressKey(allEpisodes.map((e) => e.audioUrl));
        final progressAsync = ref.watch(episodeProgressProvider(urlsKey));

        return progressAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(child: Text('Hata: $e')),
          data: (progressMap) {
            final episodes = filterEpisodes(
              episodes: allEpisodes,
              filter: _filter,
              progressMap: progressMap,
              query: _query,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PodcastCover(imageUrl: feed.imageUrl, size: 200, borderRadius: 12),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feed.title,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                  letterSpacing: -0.02,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${allEpisodes.length} bölüm',
                                style: const TextStyle(fontSize: 14, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Bölümleri yenile',
                          icon: const Icon(Icons.refresh),
                          onPressed: () => _refreshFeed(feed),
                        ),
                        IconButton(
                          tooltip: 'Abonelikten çık',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _unsubscribe(feed),
                        ),
                      ],
                    ),
                  ),
                _continueSection(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ...EpisodeFilter.values.map((f) {
                      return DesignFilterChip(
                        label: f.label,
                        selected: _filter == f,
                        onTap: () => setState(() => _filter = f),
                      );
                    }),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Bölümlerde ara',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'BÖLÜMLER',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.08,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: episodes.isEmpty
                      ? Center(
                          child: Text(
                            _filter == EpisodeFilter.unlistened
                                ? 'Dinlenmemiş bölüm kalmadı'
                                : _query.trim().isNotEmpty
                                    ? 'Aramayla eşleşen bölüm yok'
                                : _filter == EpisodeFilter.downloaded
                                    ? 'İndirilmiş bölüm yok'
                                    : 'Henüz bölüm yok',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: episodes.length,
                          itemBuilder: (context, i) {
                            final ep = episodes[i];
                            final isCurrent = currentUrl == ep.audioUrl;
                            final progress = progressMap[ep.audioUrl];
                            final dl = downloadProgress[ep.audioUrl];

                            return StreamBuilder(
                              stream: player.playerStateStream,
                              builder: (context, snap) {
                                final playing = isCurrent && (snap.data?.playing ?? false);
                                return EpisodeRow(
                                  episode: ep,
                                  progress: progress,
                                  playing: playing,
                                  isCurrent: isCurrent,
                                  downloadProgress: dl,
                                  onTap: () => _togglePlay(feed, ep, playing, isCurrent),
                                  onPlay: () => _togglePlay(feed, ep, playing, isCurrent),
                                  onMenu: () => _showEpisodeMenu(feed, ep),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _mobileFeedList(List<PodcastFeed> feeds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Podcastlerim',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  final count = await ref.read(refreshAllFeedsProvider.future);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$count podcast güncellendi')),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Podcast ekle',
                onPressed: () => showAddPodcastDialog(context, ref),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: feeds.length,
            itemBuilder: (_, i) {
              final f = feeds[i];
              final selected = f.id == _selected?.id;
              return SizedBox(
                width: 72,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selected = f),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PodcastCover(
                            imageUrl: f.imageUrl,
                            size: 56,
                            borderRadius: selected ? 12 : 8,
                          ),
                          if (selected) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_selected != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selected!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.foreground),
                  ),
                ),
                IconButton(
                  tooltip: 'Abonelikten çık',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _unsubscribe(_selected!),
                ),
              ],
            ),
          ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedsAsync = ref.watch(feedsProvider);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint;

    return feedsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (feeds) {
        if (feeds.isEmpty) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.headphones, size: 64, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'Podcast dinlemeye başla',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.foreground),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Favori programlarını ekle, bölümleri dinle, kaldığın yerden devam et.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: () => showAddPodcastDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Podcast ekle'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _importOpml,
                        child: const Text('OPML dosyasından içe aktar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        _selected ??= feeds.first;
        if (!feeds.any((f) => f.id == _selected!.id)) {
          _selected = feeds.first;
        }

        if (wide) {
          return Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sidebar(feeds),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 32, 24),
                    child: _episodesPanel(_selected!),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _mobileFeedList(feeds),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _episodesPanel(_selected!, showHeader: false),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
