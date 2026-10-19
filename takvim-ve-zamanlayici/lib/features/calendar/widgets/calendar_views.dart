import 'package:flutter/material.dart';

import '../../../core/date_utils.dart';
import '../../../core/recurrence.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/models/calendar_event.dart';

class EventChip extends StatelessWidget {
  const EventChip({
    super.key,
    required this.title,
    required this.colorIndex,
    required this.onTap,
    this.timeLabel,
    this.compact = false,
  });

  final String title;
  final int colorIndex;
  final VoidCallback onTap;
  final String? timeLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = AppColors.eventBorder(colorIndex);

    return Material(
      color: AppColors.eventBackground(colorIndex, dark: isDark),
      borderRadius: BorderRadius.circular(6),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: border, width: 3),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 6,
            vertical: compact ? 2 : 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              if (timeLabel != null && !compact)
                Text(
                  timeLabel!,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color eventAccent(CalendarEvent event) =>
    AppColors.eventBorder(event.colorIndex);

class WeekView extends StatelessWidget {
  const WeekView({
    super.key,
    required this.anchor,
    required this.occurrences,
    required this.onEventTap,
    this.onSlotTap,
  });

  final DateTime anchor;
  final List<EventOccurrence> occurrences;
  final ValueChanged<EventOccurrence> onEventTap;
  final void Function(DateTime day, int hour)? onSlotTap;

  static const _slotHeight = AppLayout.slotHeight;
  static const _startHour = 8;
  static const _endHour = 20;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final gridBg = isDark ? AppColors.bgGridDark : AppColors.bgGridLight;
    final weekStart = startOfWeek(anchor);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final now = DateTime.now();
    final showNowLine = days.any((d) => isSameDay(d, now));
    final allDay = occurrences.where((o) => o.event.isAllDay).toList();
    final timed = occurrences.where((o) => !o.event.isAllDay).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const labelW = AppLayout.hourLabelWidth;
        final dayWidth = (constraints.maxWidth - labelW) / 7;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: gridBg,
                border: Border(bottom: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: labelW,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'Tüm gün',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ),
                  ),
                  ...List.generate(7, (i) {
                    final dayEvents = allDay.where((o) => isSameDay(o.start, days[i]));
                    return SizedBox(
                      width: dayWidth,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: border)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: dayEvents.map((o) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: EventChip(
                                title: o.event.title,
                                colorIndex: o.event.colorIndex,
                                compact: true,
                                onTap: () => onEventTap(o),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SizedBox(
                  height: (_endHour - _startHour) * _slotHeight + 72,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            height: 72,
                            child: Row(
                              children: [
                                const SizedBox(width: labelW),
                                ...days.map(
                                  (d) => SizedBox(
                                    width: dayWidth,
                                    child: _DayHeader(day: d, isDark: isDark, border: border),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: labelW,
                                  child: Column(
                                    children: List.generate(_endHour - _startHour, (i) {
                                      final hour = _startHour + i;
                                      return SizedBox(
                                        height: _slotHeight,
                                        child: Align(
                                          alignment: Alignment.topRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 8, top: 2),
                                            child: Text(
                                              '${hour.toString().padLeft(2, '0')}:00',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                color: isDark
                                                    ? AppColors.textMutedDark
                                                    : AppColors.textMutedLight,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                ...days.map(
                                  (d) => SizedBox(
                                    width: dayWidth,
                                    child: Column(
                                      children: List.generate(_endHour - _startHour, (i) {
                                        final hour = _startHour + i;
                                        return InkWell(
                                          onTap: onSlotTap == null
                                              ? null
                                              : () => onSlotTap!(d, hour),
                                          child: Container(
                                            height: _slotHeight,
                                            decoration: BoxDecoration(
                                              color: gridBg,
                                              border: Border(
                                                right: BorderSide(color: border),
                                                bottom: BorderSide(color: border),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ...timed.map((o) {
                        final dayIndex = days.indexWhere((d) => isSameDay(d, o.start));
                        if (dayIndex < 0) return const SizedBox.shrink();
                        final top = 72 + _offsetForTime(o.start) - _startHour * _slotHeight;
                        final height =
                            (o.end.difference(o.start).inMinutes / 60) * _slotHeight;
                        return Positioned(
                          left: labelW + dayIndex * dayWidth + 3,
                          top: top.clamp(72.0, double.infinity),
                          width: dayWidth - 6,
                          height: height.clamp(24, double.infinity),
                          child: EventChip(
                            title: o.event.title,
                            colorIndex: o.event.colorIndex,
                            timeLabel:
                                '${formatTime(o.start)}–${formatTime(o.end)}',
                            onTap: () => onEventTap(o),
                          ),
                        );
                      }),
                      if (showNowLine)
                        Positioned(
                          left: labelW,
                          right: 0,
                          top: 72 + _offsetForTime(now) - _startHour * _slotHeight,
                          child: _NowLine(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _offsetForTime(DateTime t) => (t.hour + t.minute / 60) * _slotHeight;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.isDark,
    required this.border,
  });

  final DateTime day;
  final bool isDark;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final today = isToday(day);
    final accent = AppColors.accentOf(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: border),
          bottom: BorderSide(color: border),
        ),
      ),
      child: Column(
        children: [
          Text(
            weekdayShort(day),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.02,
              color: today
                  ? accent
                  : (isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
            ),
          ),
          const SizedBox(height: 2),
          if (today)
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: Text(
                '${day.day}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          else
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
        ],
      ),
    );
  }
}

class _NowLine extends StatefulWidget {
  @override
  State<_NowLine> createState() => _NowLineState();
}

class _NowLineState extends State<_NowLine> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final opacity = reduceMotion ? 1.0 : Tween(begin: 0.55, end: 1.0).animate(_pulse).value;

    return Opacity(
      opacity: opacity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(height: 2, color: AppColors.nowLine),
          Positioned(
            left: -5,
            top: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.nowLine,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.month,
    required this.occurrences,
    required this.onDayTap,
    required this.onEventTap,
  });

  final DateTime month;
  final List<EventOccurrence> occurrences;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<EventOccurrence> onEventTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final days = daysInMonthGrid(month);

    return Column(
      children: [
        Row(
          children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz']
              .map(
                (d) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textMutedDark
                            : AppColors.textMutedLight,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final day = days[i];
              final inMonth = day.month == month.month;
              final dayEvents = occurrences
                  .where((o) => isSameDay(o.start, day))
                  .take(3)
                  .toList();

              return InkWell(
                onTap: () => onDayTap(day),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: border)),
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday(day) ? FontWeight.bold : null,
                          color: !inMonth
                              ? (isDark
                                  ? AppColors.textMutedDark
                                  : AppColors.textMutedLight)
                              : isToday(day)
                                  ? AppColors.accentOf(isDark)
                                  : null,
                        ),
                      ),
                      ...dayEvents.map(
                        (o) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: EventChip(
                            title: o.event.title,
                            colorIndex: o.event.colorIndex,
                            compact: true,
                            onTap: () => onEventTap(o),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class DayView extends StatelessWidget {
  const DayView({
    super.key,
    required this.day,
    required this.occurrences,
    required this.onEventTap,
  });

  final DateTime day;
  final List<EventOccurrence> occurrences;
  final ValueChanged<EventOccurrence> onEventTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayOccurrences =
        occurrences.where((o) => isSameDay(o.start, day)).toList();

    if (dayOccurrences.isEmpty) {
      return Center(
        child: Text(
          'Bu gün için etkinlik yok',
          style: TextStyle(
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: dayOccurrences.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final o = dayOccurrences[i];
        return EventChip(
          title: o.event.title,
          colorIndex: o.event.colorIndex,
          timeLabel: '${formatTime(o.start)} – ${formatTime(o.end)}',
          onTap: () => onEventTap(o),
        );
      },
    );
  }
}
