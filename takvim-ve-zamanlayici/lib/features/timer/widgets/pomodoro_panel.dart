import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/pomodoro_provider.dart';

class PomodoroPanel extends ConsumerWidget {
  const PomodoroPanel({super.key, this.linkedEventTitle});

  final String? linkedEventTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomo = ref.watch(pomodoroProvider);
    final notifier = ref.read(pomodoroProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final sidebar = isDark ? AppColors.bgSidebarDark : AppColors.bgSidebarLight;
    final accent = AppColors.accentOf(isDark);
    final ringColor = pomo.phase == PomodoroPhase.focus
        ? accent
        : (pomo.phase == PomodoroPhase.shortBreak
            ? AppColors.timerBreak
            : AppColors.success);
    final paused = !pomo.running && pomo.remainingSeconds < pomo.totalSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Odak Zamanlayıcı',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              PomodoroRing(
                progress: pomo.progress,
                label: formatPomodoroTime(pomo.remainingSeconds),
                accent: paused ? (isDark ? AppColors.borderStrongDark : AppColors.borderStrongLight) : ringColor,
                trackColor: border,
                size: 160,
                strokeWidth: 6,
                timeStyle: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.02,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                paused
                    ? 'Duraklatıldı'
                    : '${pomo.phaseLabel} · ${pomo.settings.focusMinutes} dk',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: paused ? FontWeight.w500 : FontWeight.w400,
                  color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: pomo.running ? notifier.pause : notifier.start,
                      icon: Icon(pomo.running ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(pomo.running ? 'Duraklat' : 'Başlat'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: notifier.skip,
                      child: const Text('Atla'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PomoStat(
                      value: '${pomo.completedSessions}',
                      label: 'Bugün tamamlanan',
                      sidebar: sidebar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PomoStat(
                      value: '${pomo.settings.focusMinutes}',
                      suffix: '/${pomo.settings.shortBreakMinutes}',
                      label: 'Odak / Mola dk',
                      sidebar: sidebar,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (linkedEventTitle != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sidebar,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BAĞLI ETKİNLİK',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.02,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  linkedEventTitle!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PomoStat extends StatelessWidget {
  const _PomoStat({
    required this.value,
    required this.label,
    required this.sidebar,
    this.suffix,
  });

  final String value;
  final String? suffix;
  final String label;
  final Color sidebar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sidebar,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              children: [
                TextSpan(text: value),
                if (suffix != null)
                  TextSpan(
                    text: suffix,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.02,
              color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
        ],
      ),
    );
  }
}

class PomodoroRing extends StatelessWidget {
  const PomodoroRing({
    super.key,
    required this.progress,
    required this.label,
    required this.accent,
    required this.trackColor,
    this.size = 120,
    this.strokeWidth = 6,
    this.timeStyle,
  });

  final double progress;
  final String label;
  final Color accent;
  final Color trackColor;
  final double size;
  final double strokeWidth;
  final TextStyle? timeStyle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Pomodoro kalan süre $label',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!reduceMotion)
              CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: strokeWidth,
                backgroundColor: trackColor,
                color: accent,
              )
            else
              Container(
                width: size - strokeWidth * 2,
                height: size - strokeWidth * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: trackColor, width: strokeWidth),
                ),
              ),
            Text(
              label,
              style: timeStyle ??
                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
