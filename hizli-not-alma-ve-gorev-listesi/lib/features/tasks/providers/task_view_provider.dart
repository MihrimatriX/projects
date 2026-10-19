import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/task_filters.dart';
import '../../projects/models/project_item.dart';
import '../../tags/models/tag_item.dart';

final taskViewProvider = StateProvider<TaskView>(
  (ref) => const TaskView(TaskViewKind.today),
);

void selectNavView(WidgetRef ref, TaskViewKind kind) {
  ref.read(taskViewProvider.notifier).state = TaskView(kind);
}

void selectProjectView(WidgetRef ref, ProjectItem project) {
  ref.read(taskViewProvider.notifier).state =
      TaskView(TaskViewKind.project, projectId: project.id);
}

void selectTagView(WidgetRef ref, TagItem tag) {
  ref.read(taskViewProvider.notifier).state =
      TaskView(TaskViewKind.tag, tagId: tag.id);
}
