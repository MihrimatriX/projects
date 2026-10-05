import '../features/tasks/models/task_item.dart';
import 'date_utils.dart';
import 'task_filters.dart';

class TaskGroup {
  const TaskGroup({required this.title, required this.tasks});

  final String title;
  final List<TaskItem> tasks;
}

List<TaskGroup> groupTasks(List<TaskItem> tasks, TaskView view) {
  if (tasks.isEmpty) return const [];

  if (view.kind == TaskViewKind.today) {
    final overdue = <TaskItem>[];
    final today = <TaskItem>[];
    final done = <TaskItem>[];
    for (final t in tasks) {
      if (t.done) {
        done.add(t);
      } else if (isOverdue(t.dueDate, done: false)) {
        overdue.add(t);
      } else {
        today.add(t);
      }
    }
    return [
      if (overdue.isNotEmpty) TaskGroup(title: 'Gecikmiş', tasks: overdue),
      if (today.isNotEmpty) TaskGroup(title: 'Bugün', tasks: today),
      if (done.isNotEmpty) TaskGroup(title: 'Tamamlanan', tasks: done),
    ];
  }

  return [TaskGroup(title: '', tasks: tasks)];
}

int countOpen(List<TaskItem> tasks) => tasks.where((t) => !t.done).length;

int countOverdue(List<TaskItem> tasks) =>
    tasks.where((t) => !t.done && isOverdue(t.dueDate, done: false)).length;
