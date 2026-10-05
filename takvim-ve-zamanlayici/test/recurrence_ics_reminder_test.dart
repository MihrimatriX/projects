import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:takvim_ve_zamanlayici/core/date_utils.dart';
import 'package:takvim_ve_zamanlayici/core/ics_export.dart';
import 'package:takvim_ve_zamanlayici/core/ics_import.dart';
import 'package:takvim_ve_zamanlayici/core/notification_service.dart';
import 'package:takvim_ve_zamanlayici/core/recurrence.dart';
import 'package:takvim_ve_zamanlayici/features/events/data/events_repository.dart';
import 'package:takvim_ve_zamanlayici/features/events/models/calendar_event.dart';
import 'package:takvim_ve_zamanlayici/features/events/presentation/event_form_dialog.dart';

CalendarEvent ev(
  DateTime start, {
  RecurrenceType r = RecurrenceType.none,
  DateTime? until,
  int reminder = 0,
  Duration length = const Duration(hours: 1),
  bool allDay = false,
}) =>
    CalendarEvent(
      id: 'e${start.millisecondsSinceEpoch}',
      title: 'Etkinlik',
      start: start,
      end: start.add(length),
      recurrence: r,
      recurrenceUntil: until,
      reminderMinutes: reminder,
      isAllDay: allDay,
    );

void main() {
  group('tekrar', () {
    test('tekrar bitisi (dahil) sonrasi tekrar uretilmez', () {
      final e = ev(DateTime(2026, 6, 1, 9), r: RecurrenceType.daily, until: DateTime(2026, 6, 3));
      final occ = expandEvent(e, DateTime(2026, 5, 1), DateTime(2026, 7, 1));
      expect(occ.map((o) => o.start.day), [1, 2, 3]);
    });

    test('10 yildan eski aylik etkinlik bugun de gorunur', () {
      final e = ev(DateTime(2010, 3, 15, 10), r: RecurrenceType.monthly);
      final occ = expandEvent(e, DateTime(2026, 10, 1), DateTime(2026, 11, 1));
      expect(occ.single.start, DateTime(2026, 10, 15, 10));
    });

    test('eski gunluk/haftalik etkinlik araliga dogrudan atlar ve saat korunur', () {
      final daily = ev(DateTime(2015, 1, 1, 7, 30), r: RecurrenceType.daily);
      final occ = expandEvent(daily, DateTime(2026, 3, 28), DateTime(2026, 4, 1));
      expect(occ.length, 4);
      expect(occ.every((o) => o.start.hour == 7 && o.start.minute == 30), isTrue);

      final weekly = ev(DateTime(2020, 1, 6, 18), r: RecurrenceType.weekly); // pazartesi
      final w = expandEvent(weekly, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(w.every((o) => o.start.weekday == DateTime.monday), isTrue);
      expect(w.length, 4);
    });

    test('araliga tasan cok gunlu tekrar da bulunur', () {
      final e = ev(DateTime(2026, 1, 1, 20), r: RecurrenceType.weekly, length: const Duration(days: 2));
      final occ = expandEvent(e, DateTime(2026, 1, 9), DateTime(2026, 1, 10));
      expect(occ.single.start, DateTime(2026, 1, 8, 20));
    });

    test('addDays saati korur, ay/yil sinirini gecer', () {
      expect(addDays(DateTime(2026, 12, 31, 23, 15), 1), DateTime(2027, 1, 1, 23, 15));
      expect(addDays(DateTime(2026, 3, 1), -1), DateTime(2026, 2, 28));
    });

    test('recurrenceUntil JSON gidis-donus', () {
      final e = ev(DateTime(2026, 6, 1, 9), r: RecurrenceType.weekly, until: DateTime(2026, 8, 31));
      final back = CalendarEvent.fromJson(e.toJson());
      expect(back.recurrenceUntil, DateTime(2026, 8, 31));
      expect(CalendarEvent.fromJson(ev(DateTime(2026, 1, 1)).toJson()).recurrenceUntil, isNull);
    });
  });

  group('ICS', () {
    test('tum gun etkinligi tarih olarak yazilir ve tum gun olarak geri okunur', () {
      final e = ev(DateTime(2026, 6, 1), allDay: true, length: const Duration(days: 2));
      final ics = exportEventsToIcs([e]);
      expect(ics, contains('DTSTART;VALUE=DATE:20260601'));
      expect(ics, contains('DTEND;VALUE=DATE:20260603'));
      expect(ics, contains('\r\n'));
      final back = importEventsFromIcs(ics).single;
      expect(back.isAllDay, isTrue);
      expect(back.start, DateTime(2026, 6, 1));
      expect(back.end, DateTime(2026, 6, 3));
    });

    test('UNTIL ve hatirlatici (VALARM) gidis-donus', () {
      final e = ev(DateTime(2026, 6, 1, 9),
          r: RecurrenceType.weekly, until: DateTime(2026, 7, 6), reminder: 30);
      final ics = exportEventsToIcs([e]);
      expect(ics, contains('RRULE:FREQ=WEEKLY;UNTIL='));
      expect(ics, contains('TRIGGER:-PT30M'));
      final back = importEventsFromIcs(ics).single;
      expect(back.recurrence, RecurrenceType.weekly);
      expect(back.recurrenceUntil, DateTime(2026, 7, 6));
      expect(back.reminderMinutes, 30);
      expect(back.description, isNull, reason: 'VALARM DESCRIPTION etkinlige yazilmamali');
    });

    test('COUNT son tekrar gunune cevrilir; -PT1H30M ve -P1D tetikleyicileri', () {
      const raw = 'BEGIN:VCALENDAR\nBEGIN:VEVENT\nUID:a@x\nSUMMARY:Kurs\n'
          'DTSTART:20260105T100000\nDTEND:20260105T110000\nRRULE:FREQ=WEEKLY;COUNT=3\n'
          'BEGIN:VALARM\nTRIGGER:-PT1H30M\nEND:VALARM\nEND:VEVENT\n'
          'BEGIN:VEVENT\nUID:b@x\nSUMMARY:Tatil\nDTSTART;VALUE=DATE:20260710\n'
          'BEGIN:VALARM\nTRIGGER:-P1D\nEND:VALARM\nEND:VEVENT\nEND:VCALENDAR';
      final list = importEventsFromIcs(raw);
      expect(list[0].recurrenceUntil, DateTime(2026, 1, 19));
      expect(list[0].reminderMinutes, 90);
      expect(expandEvent(list[0], DateTime(2026, 1, 1), DateTime(2026, 3, 1)).length, 3);
      expect(list[1].isAllDay, isTrue);
      expect(list[1].end, DateTime(2026, 7, 11));
      expect(list[1].reminderMinutes, 24 * 60);
    });

    test('bozuk tarihli VEVENT atlanir, digerleri alinir', () {
      const raw = 'BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Bozuk\nDTSTART:2026AB01T100000\nEND:VEVENT\n'
          'BEGIN:VEVENT\nSUMMARY:Iyi\nDTSTART:20260601T100000\nEND:VEVENT\nEND:VCALENDAR';
      expect(importEventsFromIcs(raw).map((e) => e.title), ['Iyi']);
    });
  });

  group('uygulama ici hatirlatici', () {
    test('yalnizca araliga dusen hatirlatmalar doner', () {
      final e = ev(DateTime(2026, 6, 1, 10), reminder: 15);
      expect(NotificationService.dueReminders([e], DateTime(2026, 6, 1, 9, 40), DateTime(2026, 6, 1, 9, 44)),
          isEmpty);
      expect(NotificationService.dueReminders([e], DateTime(2026, 6, 1, 9, 44), DateTime(2026, 6, 1, 9, 45)).length,
          1);
      // Ayni an bir sonraki kontrolde tekrar gelmez.
      expect(NotificationService.dueReminders([e], DateTime(2026, 6, 1, 9, 45), DateTime(2026, 6, 1, 9, 46)),
          isEmpty);
    });

    test('uykudan donuste kacirilan ama bitmemis etkinlik hatirlatilir, bitmis olan hatirlatilmaz', () {
      final e = ev(DateTime(2026, 6, 1, 10), reminder: 15);
      expect(NotificationService.dueReminders([e], DateTime(2026, 6, 1, 8), DateTime(2026, 6, 1, 10, 30)).length, 1);
      expect(NotificationService.dueReminders([e], DateTime(2026, 6, 1, 8), DateTime(2026, 6, 1, 12)), isEmpty);
    });

    test('tekrarlayan etkinlikte o gunun tekrari; hatirlaticisiz etkinlik yok sayilir', () {
      final e = ev(DateTime(2026, 6, 1, 9), r: RecurrenceType.daily, reminder: 10);
      final due = NotificationService.dueReminders(
          [e, ev(DateTime(2026, 6, 3, 9))], DateTime(2026, 6, 3, 8, 45), DateTime(2026, 6, 3, 8, 55));
      expect(due.single.start, DateTime(2026, 6, 3, 9));
    });
  });

  group('kalicilik', () {
    test('bozuk kayit bos takvim doner ve ham veri yedeklenir', () async {
      SharedPreferences.setMockInitialValues({'events_v2': '[{bozuk'});
      expect(await EventsRepository().load(), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(EventsRepository.backupKey), '[{bozuk');
    });

    test('tek bozuk girdi atlanir, digerleri yuklenir', () async {
      final good = ev(DateTime(2026, 6, 1, 9)).toJson();
      SharedPreferences.setMockInitialValues({
        'events_v2': jsonEncode([{'id': 'x'}, good]),
      });
      final list = await EventsRepository().load();
      expect(list.single.id, good['id']);
    });
  });

  testWidgets('standart disi hatirlatici ve aralik disi tarihli etkinlik formu acilir; tekrar bitisi gorunur',
      (tester) async {
    await initializeDateFormatting('tr_TR');
    final e = ev(DateTime(2040, 1, 5, 9), r: RecurrenceType.weekly, until: DateTime(2040, 3, 1), reminder: 45);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEventFormDialog(context, existing: e),
            child: const Text('ac'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    expect(find.text('45 dk önce'), findsOneWidget);
    expect(find.byKey(const Key('recurrence-until')), findsOneWidget);
    expect(find.text('1 Mar 2040'), findsOneWidget);
    await tester.tap(find.text('Başlangıç'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

