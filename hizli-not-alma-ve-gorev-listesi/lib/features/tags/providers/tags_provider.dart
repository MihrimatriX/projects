import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../data/tags_repository.dart';
import '../models/tag_item.dart';

final tagsRepositoryProvider = Provider(
  (ref) => TagsRepository(ref.watch(databaseProvider)),
);

final tagsProvider =
    AsyncNotifierProvider<TagsNotifier, List<TagItem>>(TagsNotifier.new);

class TagsNotifier extends AsyncNotifier<List<TagItem>> {
  TagsRepository get _repo => ref.read(tagsRepositoryProvider);

  @override
  Future<List<TagItem>> build() => _repo.loadAll();

  Future<void> reload() async {
    state = AsyncData(await _repo.loadAll());
  }

  Future<List<TagItem>> ensureAll(List<String> names) async {
    final items = <TagItem>[];
    for (final n in names) {
      items.add(await _repo.ensureTag(n));
    }
    await reload();
    return items;
  }
}
