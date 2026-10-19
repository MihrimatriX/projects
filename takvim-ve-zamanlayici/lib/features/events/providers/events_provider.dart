import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ics_import.dart';
import '../../../core/notification_service.dart';
import '../data/events_repository.dart';
import '../models/calendar_event.dart';

final eventsRepositoryProvider = Provider((ref) => EventsRepository());

final eventSearchQueryProvider = StateProvider<String>((ref) => '');

final eventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<CalendarEvent>>(
  EventsNotifier.new,
);

class EventsNotifier extends AsyncNotifier<List<CalendarEvent>> {
  EventsRepository get _repo => ref.read(eventsRepositoryProvider);

  @override
  Future<List<CalendarEvent>> build() async {
    final events = await _repo.load();
    await NotificationService.rescheduleEventReminders(events);
    return events;
  }

  Future<void> _persist(List<CalendarEvent> updated) async {
    await _repo.save(updated);
    state = AsyncData(updated);
    await NotificationService.rescheduleEventReminders(updated);
  }

  Future<void> add(CalendarEvent event) async {
    final current = state.value ?? [];
    final updated = [...current, event]..sort((a, b) => a.start.compareTo(b.start));
    await _persist(updated);
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final current = state.value ?? [];
    final updated = current.map((e) => e.id == event.id ? event : e).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    await _persist(updated);
  }

  Future<void> remove(String id) async {
    final current = state.value ?? [];
    final updated = current.where((e) => e.id != id).toList();
    await _persist(updated);
  }

  Future<void> clearAll() async {
    await _repo.clear();
    state = const AsyncData([]);
    await NotificationService.cancelAllEventReminders();
  }

  Future<int> importEvents(List<CalendarEvent> imported, {bool merge = true}) async {
    if (imported.isEmpty) return 0;
    final current = merge ? (state.value ?? []) : <CalendarEvent>[];
    final existingIds = current.map((e) => e.id).toSet();
    var added = 0;
    final updated = [...current];
    for (final event in imported) {
      if (existingIds.contains(event.id)) continue;
      updated.add(event);
      added++;
    }
    updated.sort((a, b) => a.start.compareTo(b.start));
    await _persist(updated);
    return added;
  }

  Future<int> importFromIcs(String raw, {bool merge = true}) async {
    final parsed = importEventsFromIcs(raw);
    return importEvents(parsed, merge: merge);
  }

  Future<int> importFromJson(String raw, {bool merge = true}) async {
    final list = jsonDecode(raw) as List<dynamic>;
    final events = list
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    return importEvents(events, merge: merge);
  }

  String exportToJson() {
    final events = state.value ?? [];
    return const JsonEncoder.withIndent('  ')
        .convert(events.map((e) => e.toJson()).toList());
  }
}

List<CalendarEvent> filterEventsByQuery(List<CalendarEvent> events, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return events;
  return events.where((e) {
    return e.title.toLowerCase().contains(q) ||
        (e.description?.toLowerCase().contains(q) ?? false);
  }).toList();
}
