import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/scan_history_repository.dart';

final scanHistoryRepositoryProvider =
    Provider((ref) => ScanHistoryRepository());

final scanHistoryProvider =
    AsyncNotifierProvider<ScanHistoryNotifier, List<String>>(
  ScanHistoryNotifier.new,
);

class ScanHistoryNotifier extends AsyncNotifier<List<String>> {
  ScanHistoryRepository get _repo => ref.read(scanHistoryRepositoryProvider);

  @override
  Future<List<String>> build() => _repo.load();

  Future<void> add(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? [];
    final updated = [
      trimmed,
      ...current.where((e) => e != trimmed),
    ].take(ScanHistoryRepository.maxItems).toList();
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
    final updated = items.take(ScanHistoryRepository.maxItems).toList();
    await _repo.save(updated);
    state = AsyncData(updated);
  }
}
