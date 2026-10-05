import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../habits/models/habit.dart';

class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.streak,
    this.topHabit,
    this.flexHabit,
  });

  final int streak;
  final Habit? topHabit;
  final Habit? flexHabit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppColors.contentPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AKTİF SERİ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.06,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            streak > 0 ? '$streak gün' : '—',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          if (topHabit != null) ...[
            const SizedBox(height: 8),
            Text(
              '${topHabit!.title} · Seri: ${topHabit!.streak}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (flexHabit != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.success, width: 1.5),
              ),
              child: Text(
                '${flexHabit!.flexTargetPerWeek}/7 hafta ✓',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
