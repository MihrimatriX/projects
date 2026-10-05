import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/date_utils.dart';
import '../../../core/task_filters.dart';
import '../../../core/theme/app_colors.dart';
import '../models/task_item.dart';
import '../providers/tasks_provider.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/task_row.dart';

class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key});

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider).value ?? [];
    final dayTasks = tasksOnDay(tasks, _selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _focused = DateTime(_focused.year, _focused.month - 1);
              }),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM('tr_TR').format(_focused),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() {
                _focused = DateTime(_focused.year, _focused.month + 1);
              }),
            ),
          ],
        ),
        _MonthGrid(
          focused: _focused,
          selected: _selected,
          tasks: tasks,
          onSelect: (d) => setState(() => _selected = d),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            DateFormat.yMMMMd('tr_TR').format(_selected),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: dayTasks.isEmpty
              ? const Center(
                  child: Text('Bu gün için görev yok', style: TextStyle(color: AppColors.textMuted)),
                )
              : ListView.separated(
                  itemCount: dayTasks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final task = dayTasks[i];
                    return TaskRow(
                      task: task,
                      onToggle: () => ref.read(tasksProvider.notifier).toggle(task.id),
                      onTap: () => showTaskDetailSheet(context, ref, task),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.focused,
    required this.selected,
    required this.tasks,
    required this.onSelect,
  });

  final DateTime focused;
  final DateTime selected;
  final List<TaskItem> tasks;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(focused.year, focused.month, 1);
    final daysInMonth = DateTime(focused.year, focused.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final cells = <Widget>[
      for (final w in ['Pz', 'Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct'])
        Center(child: Text(w, style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
    ];

    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(focused.year, focused.month, d);
      final count = tasksOnDay(tasks, date).where((t) => !t.done).length;
      final isSelected = isSameDay(dateOnly(date), dateOnly(selected));
      final isTodayCell = isToday(date);
      cells.add(
        InkWell(
          onTap: () => onSelect(date),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accentSoft : null,
              borderRadius: BorderRadius.circular(8),
              border: isTodayCell ? Border.all(color: AppColors.accent) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.accent : null,
                  ),
                ),
                if (count > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}
