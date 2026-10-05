import '../../projects/models/project_item.dart';
import '../../tags/models/tag_item.dart';
import 'repeat_rule.dart';
import 'subtask_item.dart';

enum TaskPriority { none, low, high }

extension TaskPriorityExt on TaskPriority {
  int get value => switch (this) {
        TaskPriority.none => 0,
        TaskPriority.low => 1,
        TaskPriority.high => 2,
      };

  static TaskPriority fromValue(int v) => switch (v) {
        2 => TaskPriority.high,
        1 => TaskPriority.low,
        _ => TaskPriority.none,
      };
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    this.done = false,
    this.dueDate,
    this.projectId,
    this.sortOrder = 0,
    this.note = '',
    this.subtasks = const [],
    this.tags = const [],
    this.priority = TaskPriority.none,
    this.repeat = RepeatRule.none,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final bool done;
  final DateTime? dueDate;
  final String? projectId;
  final int sortOrder;
  final String note;
  final List<SubtaskItem> subtasks;
  final List<TagItem> tags;
  final TaskPriority priority;
  final RepeatRule repeat;
  final DateTime createdAt;

  int get subtaskDoneCount => subtasks.where((s) => s.done).length;

  TaskItem copyWith({
    String? title,
    bool? done,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? projectId,
    bool clearProjectId = false,
    int? sortOrder,
    String? note,
    List<SubtaskItem>? subtasks,
    List<TagItem>? tags,
    TaskPriority? priority,
    RepeatRule? repeat,
  }) =>
      TaskItem(
        id: id,
        title: title ?? this.title,
        done: done ?? this.done,
        dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
        projectId: clearProjectId ? null : (projectId ?? this.projectId),
        sortOrder: sortOrder ?? this.sortOrder,
        note: note ?? this.note,
        subtasks: subtasks ?? this.subtasks,
        tags: tags ?? this.tags,
        priority: priority ?? this.priority,
        repeat: repeat ?? this.repeat,
        createdAt: createdAt,
      );
}

extension TaskItemProject on TaskItem {
  ProjectItem? projectOf(List<ProjectItem> projects) {
    if (projectId == null) return null;
    for (final p in projects) {
      if (p.id == projectId) return p;
    }
    return null;
  }
}
