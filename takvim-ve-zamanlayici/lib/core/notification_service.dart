import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../features/events/models/calendar_event.dart';
import '../features/timer/providers/pomodoro_provider.dart';
import 'recurrence.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _enabledKey = 'notifications_enabled';
  static const _pomodoroKey = 'pomodoro_notifications';
  static const pomodoroChannelId = 'pomodoro';
  static const eventChannelId = 'events';
  static const pomodoroCompleteId = 9001;

  static bool _initFailed = false;

  /// Sistem bildirimi kullanılabilir mi. flutter_local_notifications 18 Windows'u
  /// desteklemez; Windows/web'de hatırlatıcılar uygulama açıkken uygulama içinde
  /// gösterilir (bkz. [dueReminders]). Eklenti başlatılamazsa da false olur.
  static bool get supported =>
      !_initFailed && !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// [from, to] aralığında hatırlatma zamanı gelen ve henüz bitmemiş tekrarlar.
  /// Uygulama içi hatırlatıcı periyodik olarak son kontrol anından şimdiye kadar
  /// sorar; bilgisayar uykudan dönünce kaçırılanlar da (etkinlik bitmediyse) gelir.
  static List<EventOccurrence> dueReminders(
      List<CalendarEvent> events, DateTime from, DateTime to) {
    final withReminder = events.where((e) => e.reminderMinutes > 0).toList();
    if (withReminder.isEmpty) return const [];
    final maxLead = Duration(
      minutes: withReminder.map((e) => e.reminderMinutes).reduce((a, b) => a > b ? a : b),
    );
    return expandEvents(withReminder, from, to.add(maxLead)).where((o) {
      final at = o.start.subtract(Duration(minutes: o.event.reminderMinutes));
      return at.isAfter(from) && !at.isAfter(to) && o.end.isAfter(to);
    }).toList();
  }

  static Future<void> init() async {
    if (!supported) return;
    try {
      await _init();
    } catch (e) {
      // Bildirim eklentisi başlatılamazsa uygulama yine açılsın; uygulama içi
      // hatırlatıcıya düşülür.
      debugPrint('Bildirimler başlatılamadı: $e');
      _initFailed = true;
    }
  }

  static Future<void> _init() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (!enabled) await cancelAllEventReminders();
  }

  static Future<bool> isPomodoroEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pomodoroKey) ?? true;
  }

  static Future<void> setPomodoroEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pomodoroKey, enabled);
  }

  static Future<void> rescheduleEventReminders(List<CalendarEvent> events) async {
    try {
      await _rescheduleEventReminders(events);
    } catch (e) {
      // Bildirim planlanamaması etkinliğin kaydını bozmasın.
      debugPrint('Hatırlatıcılar planlanamadı: $e');
    }
  }

  static Future<void> _rescheduleEventReminders(List<CalendarEvent> events) async {
    if (!supported || !await isEnabled()) return;
    await cancelAllEventReminders();

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 30));

    // Tekrarlayan etkinlikler için ilk orijinal tarih değil, önümüzdeki 30 gündeki
    // ilk gelecek tekrarı planlanır (etkinlik başına tek bildirim kimliği var).
    final scheduled = <String>{};
    for (final occ in expandEvents(events, now, horizon.add(const Duration(hours: 1)))) {
      final event = occ.event;
      if (event.reminderMinutes <= 0 || scheduled.contains(event.id)) continue;
      final remindAt = occ.start.subtract(Duration(minutes: event.reminderMinutes));
      if (remindAt.isBefore(now) || remindAt.isAfter(horizon)) continue;
      scheduled.add(event.id);

      await _schedule(
        id: _eventNotificationId(event),
        title: event.title,
        body: '${event.reminderMinutes} dk sonra başlıyor',
        scheduled: remindAt,
        channelId: eventChannelId,
        channelName: 'Etkinlik hatırlatıcıları',
      );
    }
  }

  static Future<void> showPomodoroComplete(PomodoroPhase completedPhase) async {
    if (!supported || !await isPomodoroEnabled()) return;

    final (title, body) = switch (completedPhase) {
      PomodoroPhase.focus => ('Odak tamamlandı', 'Mola zamanı!'),
      PomodoroPhase.shortBreak => ('Mola bitti', 'Yeni odak oturumuna hazır mısın?'),
      PomodoroPhase.longBreak => ('Uzun mola bitti', 'Tekrar odaklanma zamanı'),
    };

    await _plugin.show(
      pomodoroCompleteId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          pomodoroChannelId,
          'Pomodoro',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> cancelAllEventReminders() async {
    if (!supported) return;
    // Yalnızca bekleyen etkinlik bildirimleri iptal edilir; 4000 kimliği tek tek
    // iptal etmek açılışta takvimi saniyelerce yükleme ekranında tutuyordu.
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      if (p.id >= 1000 && p.id < 5000) await _plugin.cancel(p.id);
    }
  }

  static int _eventNotificationId(CalendarEvent event) => 1000 + (event.id.hashCode.abs() % 3999);

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduled,
    required String channelId,
    required String channelName,
  }) async {
    final tzTime = tz.TZDateTime.from(scheduled, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
