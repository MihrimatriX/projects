import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/od_card.dart';
import '../../../core/widgets/page_header.dart';
import '../pomodoro_controller.dart';

class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});

  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen> {
  @override
  Widget build(BuildContext context) {
    // Durum ve sayaç pomodoroProvider'da yaşar: ekrandan çıkınca durmaz.
    final p = ref.watch(pomodoroProvider);
    final n = ref.read(pomodoroProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final now = DateTime.now();
    final remaining = p.remainingAt(now);
    final tomatoes = p.tomatoesOn(now);
    final formatted =
        '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
    final progress = p.total == 0 ? 0.0 : remaining / p.total;
    final wide = MediaQuery.sizeOf(context).width >= 760;

    final main = OdCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 4; i++)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < p.phase
                        ? AppColors.pomodoro
                        : i == p.phase && p.work && p.running
                            ? AppColors.pomodoro
                            : AppColors.border,
                    boxShadow: i == p.phase && p.work && p.running
                        ? const [BoxShadow(color: AppColors.pomodoroSoft, blurRadius: 12)]
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: AppColors.bgElevated,
                    color: p.work ? AppColors.pomodoro : AppColors.accent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 48,
                        fontWeight: FontWeight.w600,
                        color: p.work ? AppColors.pomodoro : AppColors.accent,
                      ),
                      child: Text(formatted),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.running
                          ? (p.work ? 'Odak seansı · ${p.phase}/4' : '${p.phase >= 4 ? 'Uzun' : 'Kısa'} mola · ${p.phase}/4')
                          : (remaining < p.total ? 'Duraklatıldı' : 'Hazır'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Bugün: $tomatoes domates', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!p.running)
                _PomoBtn(
                  label: 'Başlat',
                  icon: Icons.play_arrow,
                  color: AppColors.pomodoro,
                  onPressed: n.start,
                ),
              if (p.running) ...[
                _PomoBtn(label: 'Ara Ver', icon: Icons.pause, color: AppColors.pomodoro, onPressed: n.pause),
                const SizedBox(width: 10),
              ],
              _PomoBtn(label: 'Atla', icon: Icons.skip_next, color: AppColors.textSecondary, ghost: true, onPressed: n.skip),
            ],
          ),
        ],
      ),
    );

    final side = OdCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Süreler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _DurationField(label: 'Odak (dk)', value: settings.workMinutes, onChanged: ref.read(settingsProvider.notifier).setWorkMinutes)),
              const SizedBox(width: 10),
              Expanded(child: _DurationField(label: 'Mola (dk)', value: settings.breakMinutes, onChanged: ref.read(settingsProvider.notifier).setBreakMinutes)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Bugün', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          _StatRow(label: 'Tamamlanan domates', value: '$tomatoes'),
          _StatRow(label: 'Odak süresi', value: '${tomatoes * settings.workMinutes ~/ 60}s ${(tomatoes * settings.workMinutes) % 60}dk'),
        ],
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () => p.running ? n.pause() : n.start(),
        const SingleActivator(LogicalKeyboardKey.keyM): () => context.go('/timer'),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Pomodoro',
              subtitle: 'Odak seansları ve kısa molalar — faz göstergesi ile döngü takibi.',
            ),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: main), const SizedBox(width: 24), SizedBox(width: 280, child: side)],
              )
            else
              Column(children: [main, const SizedBox(height: 24), side]),
          ],
        ),
      ),
    );
  }
}

class _PomoBtn extends StatelessWidget {
  const _PomoBtn({required this.label, required this.icon, required this.color, required this.onPressed, this.ghost = false});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    if (ghost) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size(120, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(140, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _DurationField extends StatelessWidget {
  const _DurationField({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final Future<void> Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: '$value',
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Consolas', color: AppColors.textPrimary),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
          onFieldSubmitted: (v) {
            final n = int.tryParse(v);
            if (n != null && n > 0) onChanged(n);
          },
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary))),
          Text(value, style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, color: AppColors.pomodoro)),
        ],
      ),
    );
  }
}
