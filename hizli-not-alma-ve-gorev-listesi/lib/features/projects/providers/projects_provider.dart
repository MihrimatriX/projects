import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../data/projects_repository.dart';
import '../models/project_item.dart';

final projectsRepositoryProvider = Provider(
  (ref) => ProjectsRepository(ref.watch(databaseProvider)),
);

final projectsProvider =
    AsyncNotifierProvider<ProjectsNotifier, List<ProjectItem>>(ProjectsNotifier.new);

class ProjectsNotifier extends AsyncNotifier<List<ProjectItem>> {
  ProjectsRepository get _repo => ref.read(projectsRepositoryProvider);

  @override
  Future<List<ProjectItem>> build() => _repo.loadAll();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = AsyncData(await _repo.loadAll());
  }

  Future<void> updateProject(ProjectItem project) async {
    await _repo.update(project);
    state = AsyncData(
      (state.value ?? []).map((p) => p.id == project.id ? project : p).toList(),
    );
  }

  Future<ProjectItem?> add(String name, {int colorIndex = 0}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final item = await _repo.insert(trimmed, colorIndex: colorIndex);
    final list = [...?state.value, item];
    state = AsyncData(list);
    return item;
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    state = AsyncData((state.value ?? []).where((p) => p.id != id).toList());
    ref.invalidate(tasksProvider);
  }
}
