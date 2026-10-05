import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database_provider.dart';
import 'now_playing.dart';
import 'queue_repository.dart';

final queueRepositoryProvider = Provider(
  (ref) => QueueRepository(ref.watch(appDatabaseProvider)),
);

final playQueueProvider =
    AsyncNotifierProvider<PlayQueueNotifier, List<NowPlaying>>(PlayQueueNotifier.new);

class PlayQueueNotifier extends AsyncNotifier<List<NowPlaying>> {
  QueueRepository get _repo => ref.read(queueRepositoryProvider);

  @override
  Future<List<NowPlaying>> build() => _repo.loadQueue();

  Future<void> reload() async {
    state = AsyncData(await _repo.loadQueue());
  }

  // Değişikliklerden önce ilk yükleme beklenir: yükleme sürerken eklenen öğe
  // listeyi tek öğeye indirip sonraki sıralamada DB'deki sırayı silebilirdi.
  Future<void> add(NowPlaying item, {bool skipIfPlaying = true}) async {
    final current = await future;
    if (current.any((e) => e.audioUrl == item.audioUrl)) return;
    await _repo.add(item);
    state = AsyncData([...current, item]);
  }

  Future<void> remove(String audioUrl) async {
    final current = await future;
    await _repo.removeByAudioUrl(audioUrl);
    state = AsyncData(current.where((e) => e.audioUrl != audioUrl).toList());
  }

  Future<void> clear() async {
    await _repo.clear();
    state = const AsyncData([]);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = <NowPlaying>[...await future];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    await _repo.replaceQueue(list);
    state = AsyncData(list);
  }
}
