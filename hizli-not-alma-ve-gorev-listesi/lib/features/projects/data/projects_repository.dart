import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/id_gen.dart';
import '../models/project_item.dart';

class ProjectsRepository {
  ProjectsRepository(this._db);

  final AppDatabase _db;

  Future<List<ProjectItem>> loadAll() async {
    final rows = await (_db.select(_db.projects)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map(
          (r) => ProjectItem(
            id: r.id,
            name: r.name,
            colorIndex: r.colorIndex,
            sortOrder: r.sortOrder,
          ),
        )
        .toList();
  }

  Future<ProjectItem> insert(String name, {int colorIndex = 0}) async {
    final id = newId();
    final count = await _db.select(_db.projects).get();
    final item = ProjectItem(
      id: id,
      name: name,
      colorIndex: colorIndex,
      sortOrder: count.length,
    );
    await _db.into(_db.projects).insert(
          ProjectsCompanion.insert(
            id: item.id,
            name: item.name,
            colorIndex: item.colorIndex,
            sortOrder: item.sortOrder,
          ),
        );
    return item;
  }

  Future<void> update(ProjectItem project) async {
    await (_db.update(_db.projects)..where((t) => t.id.equals(project.id)))
        .write(
      ProjectsCompanion(
        name: Value(project.name),
        colorIndex: Value(project.colorIndex),
        sortOrder: Value(project.sortOrder),
      ),
    );
  }

  Future<void> delete(String id) async {
    await (_db.update(_db.tasks)..where((t) => t.projectId.equals(id))).write(
      const TasksCompanion(projectId: Value(null)),
    );
    await (_db.delete(_db.projects)..where((t) => t.id.equals(id))).go();
  }
}
