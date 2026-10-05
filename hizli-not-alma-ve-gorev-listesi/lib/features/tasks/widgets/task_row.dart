import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/date_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../models/repeat_rule.dart';
import '../models/task_item.dart';

class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onTap,
    this.selected = false,
    this.animDuration = const Duration(milliseconds: 150),
  });

  final TaskItem task;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final bool selected;
  final Duration animDuration;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final overdue = isOverdue(task.dueDate, done: task.done);
    final dateLabel = _dueLabel(task.dueDate);
    final highPriority = task.priority == TaskPriority.high;

    return Semantics(
      checked: task.done,
      label: task.title,
      child: Material(
        color: selected ? AppColors.selectedFor(brightness) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppLayout.radiusSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppLayout.radiusSm),
          onTap: onTap,
          hoverColor: AppColors.hoverFor(brightness),
          child: Stack(
            children: [
              if (highPriority)
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppLayout.taskRowMinHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 8, 2),
                  child: Row(
                    children: [
                      _RoundCheckbox(checked: task.done, onTap: onToggle, duration: animDuration),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 15,
                                height: 20 / 15,
                                color: task.done
                                    ? AppColors.textMuted
                                    : AppColors.primaryTextFor(brightness),
                                decoration: task.done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (task.tags.isNotEmpty || task.repeat != RepeatRule.none || task.subtasks.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    ...task.tags.map((t) => Chip(label: Text(t.display))),
                                    if (task.repeat != RepeatRule.none)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.repeat, size: 14, color: AppColors.secondaryTextFor(brightness)),
                                          const SizedBox(width: 4),
                                          Text(task.repeat.label, style: TextStyle(fontSize: 11, color: AppColors.secondaryTextFor(brightness))),
                                        ],
                                      ),
                                    if (task.subtasks.isNotEmpty)
                                      Text(
                                        '${task.subtaskDoneCount}/${task.subtasks.length} alt görev',
                                        style: TextStyle(fontSize: 12, color: AppColors.secondaryTextFor(brightness)),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (dateLabel != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (overdue)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.schedule, size: 14, color: AppColors.danger),
                              ),
                            Text(
                              dateLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: overdue ? AppColors.danger : AppColors.textMuted,
                                fontWeight: overdue ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _dueLabel(DateTime? due) {
    if (due == null) return null;
    if (isToday(due)) return 'Bugün';
    if (isOverdue(due, done: task.done)) {
      final diff = DateTime.now().difference(DateTime(due.year, due.month, due.day)).inDays;
      return diff == 1 ? 'Dün' : 'Gecikmiş';
    }
    return DateFormat('d MMM', 'tr_TR').format(due);
  }
}

class _RoundCheckbox extends StatelessWidget {
  const _RoundCheckbox({required this.checked, required this.onTap, required this.duration});

  final bool checked;
  final VoidCallback onTap;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: checked,
      label: checked ? 'Tamamlandı' : 'Tamamla',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedScale(
              scale: checked ? 1 : 0.9,
              duration: duration,
              child: AnimatedContainer(
                duration: duration,
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: checked ? AppColors.accent : Colors.transparent,
                  border: Border.all(
                    color: checked ? AppColors.accent : AppColors.borderFor(Theme.of(context).brightness),
                    width: 1.5,
                  ),
                ),
                child: checked ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
