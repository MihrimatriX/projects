import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/date_utils.dart';
import '../../../core/theme/app_theme.dart';

class HeatmapGrid extends StatelessWidget {
  const HeatmapGrid({
    super.key,
    required this.counts,
    this.days = 90,
    this.columns = 15,
    this.selectedKey,
    this.onDaySelected,
    this.habitCount = 1,
  });

  final Map<String, int> counts;
  final int days;
  final int columns;
  final String? selectedKey;
  final ValueChanged<String>? onDaySelected;
  final int habitCount;

  @override
  Widget build(BuildContext context) {
    final keys = AppDates.lastNDays(days);
    final maxCount = habitCount.clamp(1, 999);
    final todayKey = AppDates.todayKey();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MonthLabels(keys: keys, columns: columns),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 3,
            mainAxisSpacing: 3,
          ),
          itemCount: keys.length,
          itemBuilder: (context, index) {
            final key = keys[index];
            final count = counts[key] ?? 0;
            final selected = key == selectedKey;
            final isToday = key == todayKey;

            return Semantics(
              label: '${AppDates.formatShort(AppDates.parseKey(key))}, $count tamamlama',
              button: onDaySelected != null,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDaySelected == null ? null : () => onDaySelected!(key),
                  borderRadius: BorderRadius.circular(3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    decoration: BoxDecoration(
                      color: _levelColor(count, maxCount),
                      borderRadius: BorderRadius.circular(3),
                      border: isToday
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Az', style: TextStyle(fontSize: 11, color: AppTheme.muted(context))),
            const SizedBox(width: 8),
            for (final c in const [
              AppColors.heatmap0,
              AppColors.heatmap1,
              AppColors.heatmap2,
              AppColors.heatmap3,
              AppColors.heatmap4,
            ])
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
              ),
            const SizedBox(width: 8),
            Text('Çok', style: TextStyle(fontSize: 11, color: AppTheme.muted(context))),
            const SizedBox(width: 8),
            Text(
              '· 0–$maxCount / gün',
              style: TextStyle(fontSize: 11, color: AppTheme.muted(context)),
            ),
          ],
        ),
      ],
    );
  }

  Color _levelColor(int count, int max) {
    if (count == 0) return AppColors.heatmap0;
    if (max <= 1) return AppColors.heatmap4;
    final ratio = count / max;
    if (ratio <= 0.25) return AppColors.heatmap1;
    if (ratio <= 0.5) return AppColors.heatmap2;
    if (ratio <= 0.75) return AppColors.heatmap3;
    return AppColors.heatmap4;
  }
}

class _MonthLabels extends StatelessWidget {
  const _MonthLabels({required this.keys, required this.columns});

  final List<String> keys;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final spans = <_MonthSpan>[];
    String? currentMonth;
    var start = 0;

    for (var i = 0; i < keys.length; i++) {
      final month = DateFormat('MMM', 'tr_TR').format(AppDates.parseKey(keys[i]));
      if (currentMonth == null) {
        currentMonth = month;
        start = i;
      } else if (month != currentMonth) {
        spans.add(_MonthSpan(label: currentMonth, start: start, length: i - start));
        currentMonth = month;
        start = i;
      }
    }
    if (currentMonth != null) {
      spans.add(_MonthSpan(label: currentMonth, start: start, length: keys.length - start));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 3,
        mainAxisSpacing: 3,
        childAspectRatio: 3,
      ),
      itemCount: columns,
      itemBuilder: (context, index) {
        final span = spans.where((s) => index >= s.start && index < s.start + s.length).firstOrNull;
        if (span == null || index != span.start) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            span.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.06,
              color: AppTheme.muted(context),
            ),
          ),
        );
      },
    );
  }
}

class _MonthSpan {
  const _MonthSpan({required this.label, required this.start, required this.length});

  final String label;
  final int start;
  final int length;
}
