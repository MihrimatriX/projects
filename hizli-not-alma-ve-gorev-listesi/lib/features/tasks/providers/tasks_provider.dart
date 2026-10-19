import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/prefs_provider.dart';
import '../../../core/recurrence.dart';
import '../../../core/task_filters.dart';
import '../../../core/task_input_parser.dart';
import '../../tags/providers/tags_provider.dart';
import '../data/tasks_repository.dart';
import '../models/repeat_rule.dart';
import '../models/task_item.dart';
import 'task_view_provider.dart';

final tasksRepositoryProvider = Provider(
  (ref) => TasksRepository(ref.watch(databaseProvider)),
);

final tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<TaskItem>>(TasksNotifier.new);

final filteredTasksProvider = Provider<AsyncValue<List<TaskItem>>>((ref) {
  final tasks = ref.watch(tasksProvider);
  final view = ref.watch(taskViewProvider);
  final showCompleted = ref.watch(showCompletedProvider);
  final search = ref.watch(searchQueryProvider);
  return tasks.whenData(
    (list) => filterTasks(
      list,
      view,
      showCompleted: showCompleted,
      searchQuery: search,
    ),
  );
});

// Tüm görevler bellekte tek liste olarak tutulur; her işlem önce SQLite'a
// yazar, sonra state'i günceller. Görünüm/arama filtresi filteredTasksProvider'da.
class TasksNotifier extends AsyncNotifier<List<TaskItem>> {
  TasksRepository get _repo => ref.read(tasksRepositoryProvider);

  @override
  Future<List<TaskItem>> build() => _repo.loadAll();

  Future<void> reload() async {
    state = AsyncData(await _repo.loadAll());
  }

  String? get _defaultProjectId {
    final view = ref.read(taskViewProvider);
    return view.kind == TaskViewKind.project ? view.projectId : null;
  }

  Future<void> add(String raw, {DateTime? dueDate}) async {
    final parsed = parseTaskInput(raw);
    if (parsed.title.isEmpty) return;

    final tagItems = await ref.read(tagsProvider.notifier).ensureAll(parsed.allTagNames);
    final task = await _repo.insert(
      title: parsed.title,
      projectId: _defaultProjectId,
      dueDate: dueDate ?? _defaultDueForView(),
      tagIds: tagItems.map((t) => t.id).toList(),
    );
    state = AsyncData([...(state.value ?? []), task]);
  }

  DateTime? _defaultDueForView() {
    final kind = ref.read(taskViewProvider).kind;
    if (kind == TaskViewKind.today || kind == TaskViewKind.calendar) {
      return DateTime.now();
    }
    return null;
  }

  Future<void> toggle(String id) async {
    final current = (state.value ?? []).firstWhere((t) => t.id == id);
    final nowDone = !current.done;

    // Tekrarlayan görev tamamlanınca bu kayıt kapanır, sonraki tarihle yeni görev açılır.
    if (nowDone && current.repeat != RepeatRule.none) {
      await _repo.update(current.copyWith(done: true));
      final nextDue = nextDueDate(current.dueDate, current.repeat);
      final next = await _repo.insert(
        title: current.title,
        projectId: current.projectId,
        dueDate: nextDue,
        tagIds: current.tags.map((t) => t.id).toList(),
        priority: current.priority,
        repeat: current.repeat,
      );
      state = AsyncData([
        ...(state.value ?? []).map((t) => t.id == id ? t.copyWith(done: true) : t),
        next,
      ]);
      return;
    }

    final updated = (state.value ?? []).map((t) {
      if (t.id != id) return t;
      return t.copyWith(done: nowDone);
    }).toList();
    final task = updated.firstWhere((t) => t.id == id);
    await _repo.update(task);
    state = AsyncData(updated);
  }

  Future<void> saveTask(TaskItem task) async {
    await _repo.update(task);
    state = AsyncData(
      (state.value ?? []).map((t) => t.id == task.id ? task : t).toList(),
    );
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = AsyncData((state.value ?? []).where((t) => t.id != id).toList());
  }

  Future<void> reorder(List<TaskItem> visibleOrdered) async {
    await _repo.reorder(visibleOrdered.map((t) => t.id).toList());
    await reload();
  }

  Future<void> addSubtask(String taskId, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final sub = await _repo.addSubtask(taskId, trimmed);
    state = AsyncData(
      (state.value ?? []).map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(subtasks: [...t.subtasks, sub]);
      }).toList(),
    );
  }

  Future<void> toggleSubtask(String taskId, String subId) async {
    final updated = (state.value ?? []).map((t) {
      if (t.id != taskId) return t;
      final subs = t.subtasks.map((s) {
        if (s.id != subId) return s;
        final next = s.copyWith(done: !s.done);
        _repo.updateSubtask(next);
        return next;
      }).toList();
      return t.copyWith(subtasks: subs);
    }).toList();
    state = AsyncData(updated);
  }

  Future<void> removeSubtask(String taskId, String subId) async {
    await _repo.deleteSubtask(subId);
    state = AsyncData(
      (state.value ?? []).map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(
          subtasks: t.subtasks.where((s) => s.id != subId).toList(),
        );
      }).toList(),
    );
  }
}
