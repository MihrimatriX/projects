import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/format.dart';

import '../../../core/platform/platform_info.dart';

import '../../../core/player/player_provider.dart';

import '../../../core/theme/app_theme.dart';

import '../../feeds/models/podcast_feed.dart';

import '../../feeds/providers/episodes_provider.dart';

import '../../feeds/providers/feeds_provider.dart';

import '../../feeds/widgets/podcast_cover.dart';



class DownloadsScreen extends ConsumerWidget {

  const DownloadsScreen({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    if (!PlatformInfo.supportsOfflineDownload) {

      return Scaffold(

        appBar: AppBar(title: const Text('İndirilenler')),

        body: const Center(

          child: Padding(

            padding: EdgeInsets.all(32),

            child: Text(

              'Web sürümünde offline indirme yok.\n\nBölümleri doğrudan dinleyebilirsin.',

              textAlign: TextAlign.center,

              style: TextStyle(color: AppColors.muted, height: 1.5),

            ),

          ),

        ),

      );

    }



    final feeds = ref.watch(feedsProvider).value ?? [];

    if (feeds.isEmpty) {

      return Scaffold(

        appBar: AppBar(title: const Text('İndirilenler')),

        body: const Center(

          child: Text(

            'Henüz podcast yok',

            style: TextStyle(color: AppColors.muted),

          ),

        ),

      );

    }



    return Scaffold(

      appBar: AppBar(title: const Text('İndirilen bölümler')),

      body: ListView.builder(

        padding: const EdgeInsets.all(16),

        itemCount: feeds.length,

        itemBuilder: (context, fi) {

          final feed = feeds[fi];

          return _FeedDownloads(feed: feed);

        },

      ),

    );

  }

}



class _FeedDownloads extends ConsumerWidget {

  const _FeedDownloads({required this.feed});



  final PodcastFeed feed;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final episodesAsync = ref.watch(episodesProvider(feed));



    return episodesAsync.when(

      loading: () => const SizedBox.shrink(),

      error: (_, __) => const SizedBox.shrink(),

      data: (all) {

        final downloaded = all.where((e) => e.localPath != null).toList();

        if (downloaded.isEmpty) return const SizedBox.shrink();



        return Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Padding(

              padding: const EdgeInsets.only(bottom: 8, top: 8),

              child: Row(

                children: [

                  PodcastCover(imageUrl: feed.imageUrl, size: 32),

                  const SizedBox(width: 12),

                  Expanded(

                    child: Text(

                      feed.title,

                      style: const TextStyle(color: AppColors.foreground, fontWeight: FontWeight.w600),

                    ),

                  ),

                ],

              ),

            ),

            ...downloaded.map((ep) {

              return ListTile(

                title: Text(ep.title, maxLines: 2, overflow: TextOverflow.ellipsis),

                subtitle: ep.duration != null ? Text(formatDurationShort(ep.duration!)) : null,

                trailing: Material(

                  color: AppColors.primary,

                  shape: const CircleBorder(),

                  child: IconButton(

                    tooltip: 'Dinle',

                    icon: const Icon(Icons.play_arrow, color: Colors.black),

                    onPressed: () async {

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

                        if (context.mounted) {

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));

                        }

                      }

                    },

                  ),

                ),

              );

            }),

            const Divider(color: AppColors.border),

          ],

        );

      },

    );

  }

}


