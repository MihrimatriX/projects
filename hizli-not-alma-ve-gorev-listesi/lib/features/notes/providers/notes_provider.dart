import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/id_gen.dart';
import '../../../core/text_search.dart';
import '../data/notes_repository.dart';
import '../models/note_item.dart';

final notesRepositoryProvider = Provider(
  (ref) => NotesRepository(ref.watch(databaseProvider)),
);

/// Not metninde Türkçe duyarlı arama.
List<NoteItem> filterNotes(List<NoteItem> notes, String query) =>
    notes.where((n) => matchesSearch(n.text, query)).toList();

final quickNotesProvider =
    AsyncNotifierProvider<QuickNotesNotifier, List<NoteItem>>(QuickNotesNotifier.new);

class QuickNotesNotifier extends AsyncNotifier<List<NoteItem>> {
  NotesRepository get _repo => ref.read(notesRepositoryProvider);

  @override
  Future<List<NoteItem>> build() => _repo.loadAll();

  Future<void> add(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final note = NoteItem(
      id: newId(),
      text: trimmed,
      updatedAt: DateTime.now(),
    );
    await _repo.insert(note);
    state = AsyncData([note, ...(state.value ?? [])]);
  }

  /// Not metnini günceller; boş metin kaydedilmez (silme ayrı bir eylem).
  Future<void> edit(String id, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? [];
    final old = current.where((n) => n.id == id).firstOrNull;
    if (old == null || old.text == trimmed) return;
    final updated = NoteItem(id: id, text: trimmed, updatedAt: DateTime.now());
    await _repo.update(updated);
    state = AsyncData([updated, ...current.where((n) => n.id != id)]);
  }

  /// Notu siler ve geri alma için silinen notu döndürür.
  Future<NoteItem?> remove(String id) async {
    final removed = (state.value ?? []).where((n) => n.id == id).firstOrNull;
    await _repo.delete(id);
    state = AsyncData((state.value ?? []).where((n) => n.id != id).toList());
    return removed;
  }

  /// Silinen notu aynı kimlik ve tarihle geri koyar.
  Future<void> restore(NoteItem note) async {
    await _repo.insert(note);
    final list = [note, ...(state.value ?? []).where((n) => n.id != note.id)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = AsyncData(list);
  }
}
