import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../habits/models/habit.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.onToggle,
    this.onLongPress,
  });

  final Habit habit;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final accent = Color(habit.color);

    return Material(
      color: habit.doneToday ? AppTheme.successBg(context) : Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        onTap: onToggle,
        onLongPress: onLongPress,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(color: AppTheme.border(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Text(habit.icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _meta(),
                        style: TextStyle(fontSize: 12, color: AppTheme.muted(context)),
                      ),
                    ],
                  ),
                ),
                _CheckButton(done: habit.doneToday, accent: accent, onTap: onToggle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _meta() {
    final freq = habit.frequency == HabitFrequency.daily ? 'Günlük' : 'Haftalık';
    if (habit.flexStreakEnabled && habit.frequency == HabitFrequency.daily) {
      return 'Esnek streak · Haftalık ${habit.flexTargetPerWeek}/7';
    }
    if (habit.streak > 0) return '${habit.streak} gün seri · $freq';
    return freq;
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.accent, required this.onTap});

  final bool done;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: true,
      label: done ? 'Tamamlandı' : 'Tamamla',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusCheck),
            color: done ? AppColors.success : Colors.transparent,
            border: Border.all(
              color: done ? AppColors.success : accent,
              width: 2,
            ),
          ),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: done ? 1 : 0,
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
