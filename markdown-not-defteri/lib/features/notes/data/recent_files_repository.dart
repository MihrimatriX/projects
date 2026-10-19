import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentFilesRepository {
  static const _key = 'recent_md_files_v1';
  static const maxItems = 10;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> add(String path) async {
    final list = await load();
    list.remove(path);
    list.insert(0, path);
    while (list.length > maxItems) {
      list.removeLast();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }

  Future<void> remove(String path) async {
    final list = await load()..remove(path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list));
  }
}
