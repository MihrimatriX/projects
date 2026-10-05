import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/qr_history_repository.dart';

final qrHistoryRepositoryProvider =
    Provider((ref) => QrHistoryRepository());

final qrHistoryProvider =
    AsyncNotifierProvider<QrHistoryNotifier, List<String>>(
  QrHistoryNotifier.new,
);

class QrHistoryNotifier extends AsyncNotifier<List<String>> {
  QrHistoryRepository get _repo => ref.read(qrHistoryRepositoryProvider);

  @override
  Future<List<String>> build() => _repo.load();

  Future<void> add(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? [];
    final updated = [trimmed, ...current.where((e) => e != trimmed)].take(50).toList();
    await _repo.save(updated);
    state = AsyncData(updated);
  }

  Future<void> remove(String value) async {
    final current = state.value ?? [];
    final updated = current.where((e) => e != value).toList();
    await _repo.save(updated);
    state = AsyncData(updated);
  }

  Future<void> clear() async {
    await _repo.save([]);
    state = const AsyncData([]);
  }

  Future<void> replaceAll(List<String> items) async {
    final updated = items.take(50).toList();
    await _repo.save(updated);
    state = AsyncData(updated);
  }
}
