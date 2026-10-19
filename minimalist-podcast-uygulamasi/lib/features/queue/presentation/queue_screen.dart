import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../core/player/player_provider.dart';

import '../../../core/player/queue_provider.dart';

import '../../../core/theme/app_theme.dart';



class QueueScreen extends ConsumerWidget {

  const QueueScreen({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final queueAsync = ref.watch(playQueueProvider);



    return Scaffold(

      appBar: AppBar(

        title: const Text('Dinleme sırası'),

        actions: [

          if ((queueAsync.value ?? []).isNotEmpty)

            TextButton(

              onPressed: () => ref.read(playQueueProvider.notifier).clear(),

              child: const Text('Temizle'),

            ),

        ],

      ),

      body: queueAsync.when(

        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),

        error: (e, _) => Center(child: Text('Hata: $e')),

        data: (queue) {

          if (queue.isEmpty) {

            return const Center(

              child: Padding(

                padding: EdgeInsets.all(32),

                child: Text(

                  'Sıra boş\n\nBölüm menüsünden «Sıraya ekle» ile dinleme listesi oluştur.',

                  textAlign: TextAlign.center,

                  style: TextStyle(color: AppColors.muted, height: 1.5),

                ),

              ),

            );

          }

          return ReorderableListView.builder(

            padding: const EdgeInsets.all(16),

            itemCount: queue.length,

            onReorderItem: (a, b) => ref.read(playQueueProvider.notifier).reorder(a, b),

            itemBuilder: (context, i) {

              final item = queue[i];

              return Card(

                key: ValueKey(item.audioUrl),

                color: AppColors.bgElevated,

                child: ListTile(

                  leading: CircleAvatar(

                    backgroundColor: AppColors.bgPlaying,

                    foregroundColor: AppColors.primary,

                    child: Text('${i + 1}'),

                  ),

                  title: Text(item.episodeTitle, maxLines: 2, overflow: TextOverflow.ellipsis),

                  subtitle: Text(item.podcastTitle),

                  trailing: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      IconButton(

                        tooltip: 'Dinle',

                        icon: const Icon(Icons.play_arrow, color: AppColors.primary),

                        onPressed: () async {
                          try {
                            await ref.read(playerProvider.notifier).playNowPlaying(item);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Oynatılamadı: $e')),
                              );
                            }
                          }
                        },

                      ),

                      IconButton(

                        icon: const Icon(Icons.close),

                        onPressed: () =>

                            ref.read(playQueueProvider.notifier).remove(item.audioUrl),

                      ),

                    ],

                  ),

                ),

              );

            },

          );

        },

      ),

    );

  }

}


