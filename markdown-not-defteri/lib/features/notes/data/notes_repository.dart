import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';

class NotesRepository {
  static const _key = 'notes_v1';

  Future<List<Note>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> save(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(notes.map((n) => n.toJson()).toList()),
    );
  }
}
