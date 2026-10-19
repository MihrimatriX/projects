import 'package:flutter_test/flutter_test.dart';
import 'package:takvim_ve_zamanlayici/core/ics_import.dart';
import 'package:takvim_ve_zamanlayici/core/natural_language_parser.dart';

void main() {
  group('parseNaturalLanguageEvent', () {
    test('parses yarin with time', () {
      final ref = DateTime(2026, 6, 3, 10);
      final result = parseNaturalLanguageEvent('Yarın 15:00 toplantı', reference: ref);
      expect(result, isNotNull);
      expect(result!.title, 'Toplantı');
      expect(result.start.day, 4);
      expect(result.start.hour, 15);
      expect(result.start.minute, 0);
    });

    test('parses bugun without time uses default hour', () {
      final ref = DateTime(2026, 6, 3, 10);
      final result = parseNaturalLanguageEvent('Bugün doktor', reference: ref);
      expect(result, isNotNull);
      expect(result!.title, 'Doktor');
      expect(result.start.day, 3);
    });

    test('cumartesi cuma olarak algilanmaz', () {
      final ref = DateTime(2026, 6, 3, 10); // Çarşamba
      final result = parseNaturalLanguageEvent('Cumartesi 11:00 piknik', reference: ref);
      expect(result!.start.weekday, DateTime.saturday);
      expect(result.title, 'Piknik');
    });
  });

  group('importEventsFromIcs', () {
    test('parses basic VEVENT', () {
      const ics = '''
BEGIN:VCALENDAR
BEGIN:VEVENT
SUMMARY:Test etkinlik
DTSTART:20260610T140000
DTEND:20260610T150000
END:VEVENT
END:VCALENDAR
''';
      final events = importEventsFromIcs(ics);
      expect(events.length, 1);
      expect(events.first.title, 'Test etkinlik');
      expect(events.first.start.hour, 14);
    });
  });
}
