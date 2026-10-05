import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../format.dart';
import '../player_provider.dart';
import '../../theme/app_theme.dart';
import '../../../features/feeds/widgets/podcast_cover.dart';

class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    if (!playerState.hasTrack) return const SizedBox.shrink();

    final track = playerState.nowPlaying!;
    final player = ref.read(playerProvider.notifier).player;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint;

    return Material(
      color: AppColors.bgPlayer,
      elevation: 12,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: wide ? AppLayout.playerHeight : AppLayout.miniPlayerHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 12),
              child: Row(
                children: [
                  if (wide) ...[
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () => context.push('/player'),
                        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              PodcastCover(imageUrl: track.imageUrl, size: 48),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track.episodeTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.foreground,
                                      ),
                                    ),
                                    Text(
                                      track.podcastTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _PlayerCenter(player: player, notifier: ref.read(playerProvider.notifier)),
                    ),
                    _SpeedButton(
                      speed: playerState.speed,
                      smartSpeed: playerState.smartSpeedActive,
                      onTap: () => ref.read(playerProvider.notifier).cycleSpeed(),
                    ),
                  ] else ...[
                    PodcastCover(imageUrl: track.imageUrl, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => context.push('/player'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.episodeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.foreground,
                              ),
                            ),
                            Text(
                              track.podcastTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    StreamBuilder<PlayerState>(
                      stream: player.playerStateStream,
                      builder: (context, snap) {
                        final playing = snap.data?.playing ?? false;
                        return Material(
                          color: AppColors.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => ref.read(playerProvider.notifier).togglePlayPause(),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCenter extends StatelessWidget {
  const _PlayerCenter({required this.player, required this.notifier});

  final dynamic player;
  final dynamic notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '15 sn geri',
              icon: const Icon(Icons.replay_10, color: AppColors.textSecondary),
              onPressed: notifier.seekBack15,
            ),
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.foreground,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(40, 40),
                  ),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 20),
                  onPressed: notifier.togglePlayPause,
                );
              },
            ),
            IconButton(
              tooltip: '30 sn ileri',
              icon: const Icon(Icons.forward_30, color: AppColors.textSecondary),
              onPressed: notifier.seekForward30,
            ),
          ],
        ),
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = player.duration ?? Duration.zero;
            final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble(),
                    max: maxMs,
                    onChanged: dur.inMilliseconds > 0
                        ? (v) => player.seek(Duration(milliseconds: v.toInt()))
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(pos), style: _mono),
                      Text(formatDuration(dur), style: _mono),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  static const _mono = TextStyle(
    fontSize: 11,
    color: AppColors.muted,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.smartSpeed, required this.onTap});

  final double speed;
  final bool smartSpeed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(52, 32),
      ),
      child: Text(
        smartSpeed ? '${speed}x SS' : '${speed}x',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
