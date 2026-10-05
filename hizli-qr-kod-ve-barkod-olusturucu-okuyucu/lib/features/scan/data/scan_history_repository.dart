import 'package:shared_preferences/shared_preferences.dart';

class ScanHistoryRepository {
  static const _key = 'scan_history_v1';
  static const maxItems = 50;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> save(List<String> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, items.take(maxItems).toList());
  }
}
