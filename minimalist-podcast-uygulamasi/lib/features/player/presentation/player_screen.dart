import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/format.dart';
import '../../../core/player/player_provider.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../feeds/widgets/podcast_cover.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  void _showSpeedMenu(BuildContext context, WidgetRef ref) {
    final state = ref.read(playerProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...playbackSpeeds.map((speed) {
              final selected = (state.speed - speed).abs() < 0.01;
              return ListTile(
                title: Text('${speed}x'),
                trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(playerProvider.notifier).setSpeed(speed);
                  Navigator.pop(ctx);
                },
              );
            }),
            const Divider(color: AppColors.border),
            Consumer(
              builder: (context, ref, _) {
                final enabled = ref.watch(appSettingsProvider).value?.smartSpeedEnabled ?? false;
                return SwitchListTile(
                  title: const Text('Smart Speed'),
                  subtitle: const Text('Sessiz bölümleri atla'),
                  value: enabled,
                  onChanged: (v) => ref.read(appSettingsProvider.notifier).setSmartSpeed(v),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSleepMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Uyku zamanlayıcı')),
            ...sleepDurations.map(
              (d) => ListTile(
                leading: const Icon(Icons.bedtime),
                title: Text('${d.inMinutes} dakika'),
                onTap: () {
                  ref.read(playerProvider.notifier).startSleepTimer(d);
                  Navigator.pop(ctx);
                },
              ),
            ),
            if (ref.read(playerProvider).sleepEndsAt != null)
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Zamanlayıcıyı iptal et'),
                onTap: () {
                  ref.read(playerProvider.notifier).cancelSleepTimer();
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final track = playerState.nowPlaying;
    if (track == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Web'de /player doğrudan açılırsa geri gidilecek sayfa yoktur.
        if (context.mounted) context.canPop() ? context.pop() : context.go('/');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final player = ref.read(playerProvider.notifier).player;
    final notifier = ref.read(playerProvider.notifier);
    final wide = MediaQuery.sizeOf(context).width > 900;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: wide
              ? _DesktopLayout(
                  track: track,
                  player: player,
                  notifier: notifier,
                  playerState: playerState,
                  onSpeed: () => _showSpeedMenu(context, ref),
                  onSleep: () => _showSleepMenu(context, ref),
                  onQueue: () => context.push('/queue'),
                  onBack: () => context.pop(),
                )
              : _MobileLayout(
                  track: track,
                  player: player,
                  notifier: notifier,
                  playerState: playerState,
                  onSpeed: () => _showSpeedMenu(context, ref),
                  onSleep: () => _showSleepMenu(context, ref),
                  onQueue: () => context.push('/queue'),
                  onBack: () => context.pop(),
                ),
        ),
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.track,
    required this.player,
    required this.notifier,
    required this.playerState,
    required this.onSpeed,
    required this.onSleep,
    required this.onQueue,
    required this.onBack,
  });

  final dynamic track;
  final dynamic player;
  final dynamic notifier;
  final PodcastPlayerState playerState;
  final VoidCallback onSpeed;
  final VoidCallback onSleep;
  final VoidCallback onQueue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Bölümlere dön'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: playerState.smartSpeedActive ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgPlaying,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'SMART SPEED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.06,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _PlayerMain(track: track, player: player, notifier: notifier, playerState: playerState, onSpeed: onSpeed, onSleep: onSleep, onQueue: onQueue)),
              if (track.chapters.isNotEmpty) ...[
                const SizedBox(width: 32),
                SizedBox(width: 320, child: _ChaptersPanel(track: track, notifier: notifier, player: player)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.track,
    required this.player,
    required this.notifier,
    required this.playerState,
    required this.onSpeed,
    required this.onSleep,
    required this.onQueue,
    required this.onBack,
  });

  final dynamic track;
  final dynamic player;
  final dynamic notifier;
  final PodcastPlayerState playerState;
  final VoidCallback onSpeed;
  final VoidCallback onSleep;
  final VoidCallback onQueue;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(onPressed: onBack, icon: const Icon(Icons.keyboard_arrow_down)),
        ),
        Expanded(
          child: _PlayerMain(
            track: track,
            player: player,
            notifier: notifier,
            playerState: playerState,
            onSpeed: onSpeed,
            onSleep: onSleep,
            onQueue: onQueue,
            compact: true,
          ),
        ),
        if (track.chapters.isNotEmpty)
          SizedBox(height: 160, child: _ChaptersPanel(track: track, notifier: notifier, player: player)),
      ],
    );
  }
}

class _PlayerMain extends StatelessWidget {
  const _PlayerMain({
    required this.track,
    required this.player,
    required this.notifier,
    required this.playerState,
    required this.onSpeed,
    required this.onSleep,
    required this.onQueue,
    this.compact = false,
  });

  final dynamic track;
  final dynamic player;
  final dynamic notifier;
  final PodcastPlayerState playerState;
  final VoidCallback onSpeed;
  final VoidCallback onSleep;
  final VoidCallback onQueue;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final artSize = compact ? 220.0 : 280.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PodcastCover(imageUrl: track.imageUrl, size: artSize, borderRadius: 12),
        const SizedBox(height: 24),
        Text(
          track.episodeTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.foreground),
        ),
        const SizedBox(height: 6),
        Text(track.podcastTitle, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
        const SizedBox(height: 24),
        StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            final dur = player.duration ?? Duration.zero;
            final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
            return SizedBox(
              width: compact ? double.infinity : 520,
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 6, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
                    child: Slider(
                      value: pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble(),
                      max: maxMs,
                      onChanged: dur.inMilliseconds > 0 ? (v) => player.seek(Duration(milliseconds: v.toInt())) : null,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(pos), style: _mono),
                      Text(formatDuration(dur), style: _mono),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.replay_10), tooltip: '15 sn geri', onPressed: notifier.seekBack15),
            StreamBuilder<PlayerState>(
              stream: player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.black, minimumSize: const Size(48, 48)),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: notifier.togglePlayPause,
                );
              },
            ),
            IconButton(icon: const Icon(Icons.forward_30), tooltip: '30 sn ileri', onPressed: notifier.seekForward30),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onSpeed,
              icon: const Icon(Icons.speed, size: 18),
              label: Text('${playerState.speed}x'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border)),
            ),
            OutlinedButton.icon(
              onPressed: onSleep,
              icon: const Icon(Icons.bedtime_outlined, size: 18),
              label: Text(playerState.sleepRemaining != null && playerState.sleepRemaining! > Duration.zero ? '${playerState.sleepRemaining!.inMinutes} dk' : 'Uyku'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border)),
            ),
            OutlinedButton.icon(
              onPressed: onQueue,
              icon: const Icon(Icons.queue_music, size: 18),
              label: const Text('Kuyruk'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary, side: const BorderSide(color: AppColors.border)),
            ),
          ],
        ),
      ],
    );
  }

  static const _mono = TextStyle(fontSize: 11, color: AppColors.muted, fontFeatures: [FontFeature.tabularFigures()]);
}

class _ChaptersPanel extends StatelessWidget {
  const _ChaptersPanel({required this.track, required this.notifier, required this.player});

  final dynamic track;
  final dynamic notifier;
  final dynamic player;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppLayout.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'BÖLÜMLER (CHAPTER)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.08, color: AppColors.muted),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                return ListView.builder(
                  itemCount: track.chapters.length,
                  itemBuilder: (context, i) {
                    final ch = track.chapters[i];
                    final nextStart = i + 1 < track.chapters.length ? track.chapters[i + 1].start : null;
                    final active = pos >= ch.start && (nextStart == null || pos < nextStart);
                    return Material(
                      color: active ? AppColors.bgPlaying : Colors.transparent,
                      child: InkWell(
                        onTap: () => notifier.seekTo(ch.start),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 3)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(formatDurationShort(ch.start), style: _ChaptersPanel._mono),
                              ),
                              Expanded(
                                child: Text(ch.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.foreground)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _mono = TextStyle(fontSize: 11, color: AppColors.muted, fontFeatures: [FontFeature.tabularFigures()]);
}
