import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/safe_json.dart';

import '../models/plan_models.dart';

class PlannerRepository {
  static const storageKey = 'week_plans_v1';
  static const _key = storageKey;

  Future<Map<String, WeekPlan>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final map = await decodeStoredJson<Map<String, dynamic>>(prefs, _key, raw);
    if (map == null) return {};
    final plans = <String, WeekPlan>{};
    for (final e in map.entries) {
      try {
        plans[e.key] = WeekPlan.fromJson(e.value as Map<String, dynamic>);
      } catch (_) {
        // Okunamayan hafta atlanir; ham veri yedeklenir.
        await prefs.setString('${_key}_bozuk_yedek', raw);
      }
    }
    return plans;
  }

  Future<WeekPlan> loadWeek(String weekStartKey) async {
    final all = await loadAll();
    return all[weekStartKey] ?? WeekPlan.empty(weekStartKey);
  }

  Future<void> saveWeek(WeekPlan plan) async {
    final all = await loadAll();
    all[plan.weekStartKey] = plan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(all.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
