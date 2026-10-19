import '../features/events/models/calendar_event.dart';
import 'date_utils.dart';

class EventOccurrence {
  const EventOccurrence({
    required this.event,
    required this.start,
    required this.end,
  });

  final CalendarEvent event;
  final DateTime start;
  final DateTime end;
}

List<EventOccurrence> expandEvents(
  List<CalendarEvent> events,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final results = <EventOccurrence>[];
  for (final event in events) {
    results.addAll(expandEvent(event, rangeStart, rangeEnd));
  }
  results.sort((a, b) => a.start.compareTo(b.start));
  return results;
}

/// Tekrarın [n]. (0 tabanlı) başlangıcı. Takvim günü/ayı ile ilerler: yaz saati
/// geçişinde saat kaymaz; aylıkta orijinal gün korunur (31 Oca -> 28 Şub -> 31 Mar).
DateTime occurrenceStart(CalendarEvent event, int n) {
  final s = event.start;
  switch (event.recurrence) {
    case RecurrenceType.none:
      return s;
    case RecurrenceType.daily:
      return addDays(s, n);
    case RecurrenceType.weekly:
      return addDays(s, 7 * n);
    case RecurrenceType.monthly:
      final first = DateTime(s.year, s.month + n);
      final day = s.day.clamp(1, _daysInMonth(first.year, first.month));
      return DateTime(first.year, first.month, day, s.hour, s.minute, s.second);
  }
}

/// Aralıkla kesişen ilk tekrarın yaklaşık sırası (alttan). Eski etkinliklerde
/// baştan saymak yerine doğrudan aralığa atlanır.
int _firstIndex(CalendarEvent event, DateTime rangeStart) {
  final s = event.start;
  if (!rangeStart.isAfter(s)) return 0;
  // UTC gün farkı: yaz saati 23/25 saatlik günleri saymayı bozmasın.
  final days = DateTime.utc(rangeStart.year, rangeStart.month, rangeStart.day)
      .difference(DateTime.utc(s.year, s.month, s.day))
      .inDays;
  final spanDays = event.end.difference(s).inDays + 1;
  final n = switch (event.recurrence) {
    RecurrenceType.none => 0,
    RecurrenceType.daily => days - spanDays,
    RecurrenceType.weekly => (days - spanDays) ~/ 7,
    RecurrenceType.monthly =>
      (rangeStart.year - s.year) * 12 + rangeStart.month - s.month - spanDays ~/ 28 - 1,
  };
  return n < 0 ? 0 : n;
}

List<EventOccurrence> expandEvent(
  CalendarEvent event,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final duration = event.end.difference(event.start);
  final until = event.recurrenceUntil == null ? null : dateOnly(event.recurrenceUntil!);
  final results = <EventOccurrence>[];

  if (event.recurrence == RecurrenceType.none) {
    if (!event.end.isBefore(rangeStart) && !event.start.isAfter(rangeEnd)) {
      results.add(EventOccurrence(event: event, start: event.start, end: event.end));
    }
    return results;
  }

  // ponytail: tek görünüm aralığı için en fazla 1000 tekrar; yıllık görünüm eklenirse artırılmalı.
  for (var n = _firstIndex(event, rangeStart), i = 0; i < 1000; n++, i++) {
    final start = occurrenceStart(event, n);
    if (start.isAfter(rangeEnd)) break;
    if (until != null && dateOnly(start).isAfter(until)) break;
    final end = start.add(duration);
    if (end.isBefore(rangeStart)) continue;
    results.add(EventOccurrence(event: event, start: start, end: end));
  }
  return results;
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

int countEventsOnDay(List<EventOccurrence> occurrences, DateTime day) {
  return occurrences.where((o) => isSameDay(o.start, day)).length;
}
