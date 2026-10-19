import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/task_filters.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/task_groups.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/tasks/models/task_item.dart';

void main() {
  test('bugün görünümünde gecikmiş ve bugün ayrılır', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final tasks = [
      TaskItem(id: '1', title: 'gecikmiş', dueDate: yesterday),
      TaskItem(id: '2', title: 'bugün', dueDate: DateTime.now()),
    ];
    final groups = groupTasks(tasks, const TaskView(TaskViewKind.today));
    expect(groups.map((g) => g.title), ['Gecikmiş', 'Bugün']);
    expect(groups.first.tasks.first.title, 'gecikmiş');
  });
}
