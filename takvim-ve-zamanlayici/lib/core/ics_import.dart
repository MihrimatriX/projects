import 'date_utils.dart';
import 'recurrence.dart';
import '../features/events/models/calendar_event.dart';

const maxIcsImportBytes = 512 * 1024;

List<CalendarEvent> importEventsFromIcs(String raw) {
  if (raw.length > maxIcsImportBytes) {
    throw const FormatException('ICS dosyası çok büyük (max ${maxIcsImportBytes ~/ 1024} KB)');
  }

  final unfolded = _unfoldIcs(raw);
  final events = <CalendarEvent>[];
  Map<String, String>? current;
  var inAlarm = false;

  for (final line in unfolded) {
    if (line == 'BEGIN:VEVENT') {
      current = {};
      inAlarm = false;
    } else if (line == 'END:VEVENT') {
      if (current != null) {
        // Bozuk tarihli tek bir VEVENT tüm içe aktarmayı düşürmesin; atlanır.
        try {
          final event = _parseVevent(current);
          if (event != null) events.add(event);
        } on FormatException {
          // atla
        }
      }
      current = null;
    } else if (line == 'BEGIN:VALARM') {
      inAlarm = true;
    } else if (line == 'END:VALARM') {
      inAlarm = false;
    } else if (current != null) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        final key = line.substring(0, idx).split(';').first.toUpperCase();
        final value = _unescape(line.substring(idx + 1));
        // VALARM'ın DESCRIPTION'ı etkinliğinkini ezmesin; yalnızca ilk TRIGGER alınır.
        if (inAlarm) {
          if (key == 'TRIGGER') current.putIfAbsent('X-TRIGGER', () => value);
        } else {
          current[key] = value;
        }
      }
    }
  }

  return events;
}

List<String> _unfoldIcs(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final result = <String>[];
  for (final line in lines) {
    if (line.startsWith(' ') || line.startsWith('\t')) {
      if (result.isNotEmpty) {
        result[result.length - 1] += line.substring(1);
      }
    } else if (line.trim().isNotEmpty) {
      result.add(line.trim());
    }
  }
  return result;
}

CalendarEvent? _parseVevent(Map<String, String> fields) {
  final summary = fields['SUMMARY'];
  final dtStart = fields['DTSTART'];
  if (summary == null || dtStart == null) return null;

  final start = _parseIcsDate(dtStart);
  if (start == null) return null;

  final dtEnd = fields['DTEND'];
  final isAllDay = !dtStart.contains('T');
  final fallbackEnd = isAllDay ? addDays(start, 1) : start.add(const Duration(hours: 1));
  final end = dtEnd != null ? _parseIcsDate(dtEnd) ?? fallbackEnd : fallbackEnd;

  final uid = fields['UID'] ?? '${start.millisecondsSinceEpoch}@import';
  final id = uid.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  final event = CalendarEvent(
    id: id.isEmpty ? start.millisecondsSinceEpoch.toString() : id,
    title: summary,
    start: start,
    end: end.isAfter(start) ? end : fallbackEnd,
    description: fields['DESCRIPTION'],
    recurrence: recurrenceFromRrule(fields['RRULE']) ?? RecurrenceType.none,
    reminderMinutes: _triggerMinutes(fields['X-TRIGGER']),
    isAllDay: isAllDay,
  );
  if (event.recurrence == RecurrenceType.none) return event;
  return event.copyWith(recurrenceUntil: _rruleUntil(fields['RRULE']!, event));
}

/// RRULE'daki UNTIL ya da COUNT son tekrar gününe çevrilir (COUNT=n: n. tekrarın günü).
/// Olmazsa süresiz tekrar kalır.
DateTime? _rruleUntil(String rrule, CalendarEvent event) {
  final parts = <String, String>{};
  for (final p in rrule.toUpperCase().split(';')) {
    final i = p.indexOf('=');
    if (i > 0) parts[p.substring(0, i)] = p.substring(i + 1);
  }
  final until = parts['UNTIL'];
  if (until != null) {
    final d = _parseIcsDate(until);
    return d == null ? null : dateOnly(d);
  }
  final count = int.tryParse(parts['COUNT'] ?? '');
  if (count != null && count > 0) return dateOnly(occurrenceStart(event, count - 1));
  return null;
}

/// "-PT15M", "-PT1H30M", "-P1D" gibi başlangıca göre negatif tetikleyiciyi dakikaya
/// çevirir. Mutlak zamanlı veya sonrası tetikleyiciler yok sayılır (0).
int _triggerMinutes(String? trigger) {
  if (trigger == null) return 0;
  final m = RegExp(r'^-P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')
      .firstMatch(trigger.trim().toUpperCase());
  if (m == null) return 0;
  int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  return g(1) * 7 * 24 * 60 + g(2) * 24 * 60 + g(3) * 60 + g(4) + g(5) ~/ 60;
}

DateTime? _parseIcsDate(String raw) {
  final value = raw.replaceAll('Z', '');
  if (value.contains('T')) {
    if (value.length >= 15) {
      // Sonu 'Z' ile biten zaman UTC'dir (dışa aktarım da böyle yazar); yerel saate çevrilir.
      // TZID'li değerler yerel saat kabul edilir.
      if (raw.endsWith('Z')) {
        return DateTime.utc(
          int.parse(value.substring(0, 4)),
          int.parse(value.substring(4, 6)),
          int.parse(value.substring(6, 8)),
          int.parse(value.substring(9, 11)),
          int.parse(value.substring(11, 13)),
          int.parse(value.substring(13, 15)),
        ).toLocal();
      }
      return DateTime(
        int.parse(value.substring(0, 4)),
        int.parse(value.substring(4, 6)),
        int.parse(value.substring(6, 8)),
        int.parse(value.substring(9, 11)),
        int.parse(value.substring(11, 13)),
        value.length >= 15 ? int.parse(value.substring(13, 15)) : 0,
      );
    }
  } else if (value.length >= 8) {
    return DateTime(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(4, 6)),
      int.parse(value.substring(6, 8)),
    );
  }
  return null;
}

String _unescape(String text) => text
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', '\\')
    .replaceAll(r'\n', '\n');
