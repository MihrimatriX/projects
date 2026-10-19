import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/safe_json.dart';

class PantryRepository {
  static const storageKey = 'pantry_v1';
  static const _key = storageKey;

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final list = await decodeStoredJson<List<dynamic>>(prefs, _key, raw);
    return {...?list?.map((e) => e.toString())};
  }

  Future<void> save(Set<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.toList()..sort()));
  }
}
