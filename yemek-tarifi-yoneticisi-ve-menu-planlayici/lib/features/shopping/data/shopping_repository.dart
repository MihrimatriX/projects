import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/safe_json.dart';

class ShoppingRepository {
  static const storageKey = 'shopping_checked_v1';
  static const _key = storageKey;

  Future<Set<String>> loadChecked(String weekStartKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final map = await decodeStoredJson<Map<String, dynamic>>(prefs, _key, raw);
    final list = map?[weekStartKey];
    if (list is! List) return {};
    return list.map((e) => e.toString()).toSet();
  }

  Future<void> saveChecked(String weekStartKey, Set<String> checked) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final map = raw == null
        ? <String, dynamic>{}
        : await decodeStoredJson<Map<String, dynamic>>(prefs, _key, raw) ?? <String, dynamic>{};
    map[weekStartKey] = checked.toList();
    await prefs.setString(_key, jsonEncode(map));
  }
}
