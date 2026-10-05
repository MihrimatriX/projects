import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/task_filters.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/tasks/models/task_item.dart';

void main() {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  final nextWeek = today.add(const Duration(days: 5));

  test('inbox only tasks without project', () {
    final tasks = [
      TaskItem(id: '1', title: 'a'),
      TaskItem(id: '2', title: 'b', projectId: 'p1'),
    ];
    final filtered = filterTasks(tasks, const TaskView(TaskViewKind.inbox));
    expect(filtered.length, 1);
    expect(filtered.first.id, '1');
  });

  test('today includes overdue and due today', () {
    final tasks = [
      TaskItem(id: '1', title: 'overdue', dueDate: yesterday),
      TaskItem(id: '2', title: 'today', dueDate: today),
      TaskItem(id: '3', title: 'later', dueDate: nextWeek),
    ];
    final filtered = filterTasks(tasks, const TaskView(TaskViewKind.today));
    expect(filtered.map((t) => t.id).toList(), containsAll(['1', '2']));
    expect(filtered.map((t) => t.id), isNot(contains('3')));
  });
}
