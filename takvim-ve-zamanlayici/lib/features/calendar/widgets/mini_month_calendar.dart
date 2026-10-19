import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/date_utils.dart';
import '../../../core/recurrence.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/models/calendar_event.dart';

class MiniMonthCalendar extends StatelessWidget {
  const MiniMonthCalendar({
    super.key,
    required this.focusedMonth,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
    required this.onMonthChanged,
    this.showSidebarActions = false,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onMonthChanged;
  final bool showSidebarActions;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final days = daysInMonthGrid(focusedMonth);
    final monthLabel = DateFormat('MMMM y', 'tr_TR').format(focusedMonth);
    final rangeStart = days.first;
    final rangeEnd = addDays(days.last, 1);
    final occurrences = expandEvents(events, rangeStart, rangeEnd);
    final weekStart = startOfWeek(selectedDay);
    final weekEnd = endOfWeek(selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthLabel,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month - 1),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => onMonthChanged(
                DateTime(focusedMonth.year, focusedMonth.month + 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: ['P', 'S', 'Ç', 'P', 'C', 'C', 'P']
              .map(
                (d) => Expanded(
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final inMonth = day.month == focusedMonth.month;
            final today = isToday(day);
            final inWeek = !day.isBefore(weekStart) && !day.isAfter(weekEnd);
            final count = countEventsOnDay(occurrences, day);

            Color? bg;
            Color fg;
            if (today) {
              bg = AppColors.accentOf(isDark);
              fg = Colors.white;
            } else if (inWeek) {
              bg = AppColors.bgHover(isDark);
              fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
            } else {
              bg = null;
              fg = inMonth
                  ? (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight)
                  : (isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight);
            }

            return Material(
              color: bg ?? Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onDaySelected(day),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 13,
                        color: fg,
                        fontWeight: today ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        bottom: 3,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: today ? Colors.white : AppColors.accentOf(isDark),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (showSidebarActions) ...[
          const SizedBox(height: 12),
          Divider(color: border, height: 1),
          const SizedBox(height: 8),
          _SidebarLink(
            icon: Icons.settings_outlined,
            label: 'Ayarlar',
            onTap: () => context.push('/settings'),
          ),
        ],
      ],
    );
  }
}

class _SidebarLink extends StatelessWidget {
  const _SidebarLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
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
