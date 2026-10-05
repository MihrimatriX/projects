import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/calendar_view_mode.dart';

class ViewSwitcher extends StatelessWidget {
  const ViewSwitcher({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgHover(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: CalendarViewMode.values.map((m) {
          final selected = m == mode;
          return Material(
            color: selected ? AppColors.accentOf(isDark) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onChanged(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text(
                  m.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.02,
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
