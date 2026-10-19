import '../features/events/models/calendar_event.dart';
import 'date_utils.dart';

String exportEventsToIcs(List<CalendarEvent> events, {String calendarName = 'Takvim'}) {
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Takvim ve Zamanlayici//TR',
    'CALSCALE:GREGORIAN',
    'X-WR-CALNAME:${_escape(calendarName)}',
  ];

  for (final event in events) {
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${event.id}@takvim.local',
      'DTSTAMP:${_icsDate(DateTime.now().toUtc())}',
      // Tüm gün etkinlikleri tarih olarak yazılır; UTC saate çevirmek onları başka
      // saat diliminde önceki güne kaydırır ve içe aktarımda "saatli" yapardı.
      if (event.isAllDay) ...[
        'DTSTART;VALUE=DATE:${_icsDay(event.start)}',
        'DTEND;VALUE=DATE:${_icsDay(event.end.isAfter(event.start) ? event.end : addDays(event.start, 1))}',
      ] else ...[
        'DTSTART:${_icsDate(event.start.toUtc())}',
        'DTEND:${_icsDate(event.end.toUtc())}',
      ],
      'SUMMARY:${_escape(event.title)}',
      if (event.description != null && event.description!.isNotEmpty)
        'DESCRIPTION:${_escape(event.description!)}',
      if (_rrule(event) case final rrule?) 'RRULE:$rrule',
      if (event.reminderMinutes > 0) ...[
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'DESCRIPTION:${_escape(event.title)}',
        'TRIGGER:-PT${event.reminderMinutes}M',
        'END:VALARM',
      ],
      'END:VEVENT',
    ]);
  }

  lines.add('END:VCALENDAR');
  // RFC 5545 satır sonu CRLF'dir.
  return '${lines.join('\r\n')}\r\n';
}

String? _rrule(CalendarEvent event) {
  final freq = switch (event.recurrence) {
    RecurrenceType.none => null,
    RecurrenceType.daily => 'FREQ=DAILY',
    RecurrenceType.weekly => 'FREQ=WEEKLY',
    RecurrenceType.monthly => 'FREQ=MONTHLY',
  };
  final until = event.recurrenceUntil;
  if (freq == null || until == null) return freq;
  // UNTIL, DTSTART ile aynı türde olmalı: tarih ya da UTC zaman (günün sonu).
  final value = event.isAllDay
      ? _icsDay(until)
      : _icsDate(addDays(dateOnly(until), 1).subtract(const Duration(seconds: 1)).toUtc());
  return '$freq;UNTIL=$value';
}

String _icsDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _icsDate(DateTime utc) {
  final h = utc.hour.toString().padLeft(2, '0');
  final mi = utc.minute.toString().padLeft(2, '0');
  final s = utc.second.toString().padLeft(2, '0');
  return '${_icsDay(utc)}T$h$mi${s}Z';
}

String _escape(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n'); // çok satırlı açıklama ICS satırını bölmesin
