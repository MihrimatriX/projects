import '../features/tasks/models/task_item.dart';
import 'date_utils.dart';
import 'text_search.dart';

enum TaskViewKind {
  today,
  inbox,
  upcoming,
  all,
  project,
  tag,
  calendar,
}

class TaskView {
  const TaskView(this.kind, {this.projectId, this.tagId});

  final TaskViewKind kind;
  final String? projectId;
  final String? tagId;

  String get title => switch (kind) {
        TaskViewKind.today => 'Bugün',
        TaskViewKind.inbox => 'Gelen Kutusu',
        TaskViewKind.upcoming => 'Yaklaşan',
        TaskViewKind.all => 'Tümü',
        TaskViewKind.project => 'Proje',
        TaskViewKind.tag => 'Etiket',
        TaskViewKind.calendar => 'Takvim',
      };
}

List<TaskItem> filterTasks(
  List<TaskItem> tasks,
  TaskView view, {
  bool showCompleted = false,
  String searchQuery = '',
}) {
  var list = switch (view.kind) {
    TaskViewKind.today => tasks.where((t) {
        if (!showCompleted && t.done) return false;
        return isToday(t.dueDate) || isOverdue(t.dueDate, done: t.done);
      }),
    TaskViewKind.inbox => tasks.where((t) {
        if (!showCompleted && t.done) return false;
        return t.projectId == null;
      }),
    TaskViewKind.upcoming => tasks.where((t) {
        if (!showCompleted && t.done) return false;
        return isUpcoming(t.dueDate, done: t.done);
      }),
    TaskViewKind.all => tasks.where((t) => showCompleted || !t.done),
    TaskViewKind.project => tasks.where((t) {
        if (view.projectId == null) return false;
        if (!showCompleted && t.done) return false;
        return t.projectId == view.projectId;
      }),
    TaskViewKind.tag => tasks.where((t) {
        if (view.tagId == null) return false;
        if (!showCompleted && t.done) return false;
        return t.tags.any((tag) => tag.id == view.tagId);
      }),
    TaskViewKind.calendar => tasks.where((t) => t.dueDate != null && (!t.done || showCompleted)),
  };

  if (searchQuery.trim().isNotEmpty) {
    list = list.where((t) =>
        matchesSearch(t.title, searchQuery) ||
        matchesSearch(t.note, searchQuery) ||
        t.tags.any((tag) => matchesSearch(tag.name, searchQuery)));
  }

  final result = list.toList()..sort(_sortTasks);
  return result;
}

List<TaskItem> tasksOnDay(List<TaskItem> tasks, DateTime day) {
  final d = dateOnly(day);
  return tasks
      .where((t) => t.dueDate != null && dateOnly(t.dueDate!) == d)
      .toList()
    ..sort(_sortTasks);
}

int countForView(List<TaskItem> tasks, TaskView view) {
  if (view.kind == TaskViewKind.all) {
    return tasks.where((t) => !t.done).length;
  }
  if (view.kind == TaskViewKind.calendar) {
    return tasks.where((t) => !t.done && t.dueDate != null).length;
  }
  return filterTasks(tasks, view).where((t) => !t.done).length;
}

int _sortTasks(TaskItem a, TaskItem b) {
  final p = b.priority.value.compareTo(a.priority.value);
  if (p != 0) return p;
  if (a.done != b.done) return a.done ? 1 : -1;
  final o = a.sortOrder.compareTo(b.sortOrder);
  if (o != 0) return o;
  return b.createdAt.compareTo(a.createdAt);
}
