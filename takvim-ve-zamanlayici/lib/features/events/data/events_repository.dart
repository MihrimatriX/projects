import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_event.dart';

class EventsRepository {
  static const _key = 'events_v2';
  static const backupKey = 'events_corrupt_backup';

  Future<List<CalendarEvent>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key) ?? prefs.getString('events_v1');
    if (raw == null) return [];
    // Bozuk kayıt takvimi açılmaz hale getirmesin. Okunamayan veri, sonraki
    // kayıt üzerine yazmadan önce yedek anahtara kopyalanır (veri kaybı yok).
    List<dynamic> list;
    try {
      list = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      await prefs.setString(backupKey, raw);
      return [];
    }
    final events = <CalendarEvent>[];
    var skipped = false;
    for (final e in list) {
      try {
        events.add(CalendarEvent.fromJson(e as Map<String, dynamic>));
      } catch (_) {
        skipped = true;
      }
    }
    if (skipped) await prefs.setString(backupKey, raw);
    events.sort((a, b) => a.start.compareTo(b.start));
    if (prefs.getString(_key) == null && events.isNotEmpty) {
      await save(events);
    }
    return events;
  }

  Future<void> save(List<CalendarEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(events.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove('events_v1');
  }
}
