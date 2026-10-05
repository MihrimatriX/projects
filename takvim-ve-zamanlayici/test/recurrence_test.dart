import 'package:flutter_test/flutter_test.dart';
import 'package:takvim_ve_zamanlayici/core/recurrence.dart';
import 'package:takvim_ve_zamanlayici/features/events/models/calendar_event.dart';

void main() {
  group('expandEvent', () {
    test('daily recurrence generates occurrences in range', () {
      final event = CalendarEvent(
        id: '1',
        title: 'Daily standup',
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 9, 30),
        recurrence: RecurrenceType.daily,
      );

      final occurrences = expandEvent(
        event,
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 6),
      );

      expect(occurrences.length, 5);
      expect(occurrences.first.start, DateTime(2026, 6, 1, 9));
      expect(occurrences.last.start, DateTime(2026, 6, 5, 9));
    });

    test('weekly recurrence skips weeks', () {
      final event = CalendarEvent(
        id: '2',
        title: 'Weekly review',
        start: DateTime(2026, 6, 3, 15),
        end: DateTime(2026, 6, 3, 16),
        recurrence: RecurrenceType.weekly,
      );

      final occurrences = expandEvent(
        event,
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 30),
      );

      expect(occurrences.length, 4);
      expect(occurrences[1].start, DateTime(2026, 6, 10, 15));
    });

    test('none recurrence only includes original event', () {
      final event = CalendarEvent(
        id: '3',
        title: 'One-off',
        start: DateTime(2026, 6, 10, 12),
        end: DateTime(2026, 6, 10, 13),
      );

      final inRange = expandEvent(
        event,
        DateTime(2026, 6, 1),
        DateTime(2026, 6, 30),
      );
      final outOfRange = expandEvent(
        event,
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 31),
      );

      expect(inRange.length, 1);
      expect(outOfRange, isEmpty);
    });

    test('monthly recurrence keeps original day after short month', () {
      final event = CalendarEvent(
        id: '4',
        title: 'Kira',
        start: DateTime(2026, 1, 31, 10),
        end: DateTime(2026, 1, 31, 11),
        recurrence: RecurrenceType.monthly,
      );

      final occurrences = expandEvent(event, DateTime(2026, 1, 1), DateTime(2026, 4, 1));

      expect(occurrences.map((o) => o.start.day), [31, 28, 31]);
    });
  });
}
