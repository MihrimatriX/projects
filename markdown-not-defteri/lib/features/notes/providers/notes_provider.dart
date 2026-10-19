import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';

final notesRepositoryProvider = Provider((ref) => NotesRepository());

final notesProvider =
    AsyncNotifierProvider<NotesNotifier, List<Note>>(NotesNotifier.new);

class NotesNotifier extends AsyncNotifier<List<Note>> {
  NotesRepository get _repo => ref.read(notesRepositoryProvider);

  @override
  Future<List<Note>> build() => _repo.load();

  // Notlar SharedPreferences'ta tek JSON listesi olarak tutulur. Değişikliklerden
  // önce `await future` ile ilk yüklemenin bitmesi beklenir; aksi halde yükleme
  // sürerken kaydetmek boş listeyi yazıp mevcut notları silebilirdi.
  Future<Note> add(String title, String body) async {
    final note = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Başlıksız' : title.trim(),
      body: body,
      updatedAt: DateTime.now(),
    );
    final current = await future;
    final updated = [note, ...current];
    await _repo.save(updated);
    state = AsyncData(updated);
    return note;
  }

  Future<void> editNote(Note note, {String? title, String? body}) async {
    final current = await future;
    final updated = current
        .map(
          (n) => n.id == note.id
              ? n.copyWith(
                  title: title ?? n.title,
                  body: body ?? n.body,
                  updatedAt: DateTime.now(),
                )
              : n,
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _repo.save(updated);
    state = AsyncData(updated);
  }

  Future<void> remove(String id) async {
    final current = await future;
    final updated = current.where((n) => n.id != id).toList();
    await _repo.save(updated);
    state = AsyncData(updated);
  }

  /// Silmeyi geri al: not aynı id ve tarihle listeye döner.
  Future<void> restore(Note note) async {
    final current = await future;
    if (current.any((n) => n.id == note.id)) return;
    final updated = [...current, note]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _repo.save(updated);
    state = AsyncData(updated);
  }
}

/// Başlık ve gövdede, Türkçe büyük/küçük harf duyarsız arama. Boş sorgu = tümü.
List<Note> filterNotes(List<Note> notes, String query) {
  final q = foldForSearch(query.trim());
  if (q.isEmpty) return notes;
  return notes
      .where((n) => foldForSearch('${n.title}\n${n.body}').contains(q))
      .toList();
}