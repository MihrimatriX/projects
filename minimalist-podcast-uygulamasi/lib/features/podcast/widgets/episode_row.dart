import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/player/playback_positions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_widgets.dart';
import '../../feeds/utils/rss_parser.dart';

class EpisodeRow extends StatelessWidget {
  const EpisodeRow({
    super.key,
    required this.episode,
    required this.progress,
    required this.playing,
    required this.isCurrent,
    required this.onTap,
    required this.onPlay,
    required this.onMenu,
    this.downloadProgress,
  });

  final PodcastEpisode episode;
  final EpisodeProgress? progress;
  final bool playing;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onMenu;
  final double? downloadProgress;

  String _meta() {
    final parts = <String>[];
    if (episode.published != null) {
      final d = episode.published!;
      const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
      parts.add('${d.day} ${months[d.month - 1]} ${d.year}');
    }
    if (playing) {
      parts.add('Oynatılıyor');
    } else if (progress?.completed == true) {
      parts.add('Dinlendi');
    } else if (progress?.position != null && progress!.position!.inSeconds > 0) {
      parts.add('Kaldığın yerden devam');
    } else {
      parts.add('Yeni bölüm');
    }
    if (episode.localPath != null) parts.add('İndirildi');
    return parts.join(' · ');
  }

  double? _progressValue() {
    final pos = progress?.position;
    final dur = episode.duration;
    if (pos == null || dur == null || dur.inMilliseconds <= 0 || progress?.completed == true) {
      return null;
    }
    return (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final played = progress?.completed == true;
    final bar = _progressValue();

    return Material(
      color: isCurrent ? AppColors.bgPlaying : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMenu,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: playing ? const EpisodeEqualizer() : const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: played ? FontWeight.w400 : FontWeight.w600,
                        color: played ? AppColors.muted : AppColors.foreground,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_meta(), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    if (bar != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: bar,
                          minHeight: 3,
                          backgroundColor: AppColors.progressBg,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (downloadProgress != null)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, value: downloadProgress, color: AppColors.primary),
                )
              else if (episode.localPath != null)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.download_done, size: 18, color: AppColors.primary),
                ),
              if (episode.duration != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    formatDurationShort(episode.duration!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              _PlayButton(playing: playing, onPressed: onPlay),
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: 'Bölüm seçenekleri',
                onPressed: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            playing ? Icons.pause : Icons.play_arrow,
            color: Colors.black,
            size: 22,
          ),
        ),
      ),
    );
  }
}
