import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _enabledKey = 'reminder_enabled';
  static const _hourKey = 'reminder_hour';
  static const _minuteKey = 'reminder_minute';
  static const _weeklyEnabledKey = 'weekly_report_enabled';
  static const _weeklyHourKey = 'weekly_report_hour';
  static const _weeklyMinuteKey = 'weekly_report_minute';

  static const dailyId = 1;
  static const weeklyId = 2;

  /// Zamanlanmış bildirimler yalnızca mobil/macOS hedeflerinde var.
  static bool get supported => _supported;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  static Future<void> init() async {
    if (!_supported) return;

    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    if (await isEnabled()) await scheduleDaily();
    if (await isWeeklyEnabled()) await scheduleWeekly();
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      await scheduleDaily();
    } else {
      await _plugin.cancel(dailyId);
    }
  }

  static Future<(int hour, int minute)> getTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_hourKey) ?? 20, prefs.getInt(_minuteKey) ?? 0);
  }

  static Future<void> setTime(int hour, int minute) async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
    if (await isEnabled()) await scheduleDaily();
  }

  static Future<bool> isWeeklyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_weeklyEnabledKey) ?? false;
  }

  static Future<void> setWeeklyEnabled(bool enabled) async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_weeklyEnabledKey, enabled);
    if (enabled) {
      await scheduleWeekly();
    } else {
      await _plugin.cancel(weeklyId);
    }
  }

  static Future<(int hour, int minute)> getWeeklyTime() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_weeklyHourKey) ?? 9, prefs.getInt(_weeklyMinuteKey) ?? 0);
  }

  static Future<void> setWeeklyTime(int hour, int minute) async {
    if (!_supported) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklyHourKey, hour);
    await prefs.setInt(_weeklyMinuteKey, minute);
    if (await isWeeklyEnabled()) await scheduleWeekly();
  }

  static Future<void> scheduleDaily() async {
    if (!_supported) return;

    final (hour, minute) = await getTime();
    await _plugin.cancel(dailyId);

    await _plugin.zonedSchedule(
      dailyId,
      'Alışkanlık hatırlatıcı',
      'Bugünkü alışkanlıklarını tamamladın mı?',
      _nextInstance(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits_daily',
          'Günlük hatırlatıcı',
          channelDescription: 'Alışkanlık tamamlama hatırlatıcıları',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> scheduleWeekly() async {
    if (!_supported) return;

    final (hour, minute) = await getWeeklyTime();
    await _plugin.cancel(weeklyId);

    await _plugin.zonedSchedule(
      weeklyId,
      'Haftalık rapor hazır',
      'Bu haftaki alışkanlık özetini uygulamadan paylaşabilirsin.',
      _nextSunday(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits_weekly',
          'Haftalık rapor',
          channelDescription: 'Haftalık alışkanlık özeti hatırlatıcısı',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> showChainReminder(String title, String icon) async {
    if (!_supported) return;
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Zincir alışkanlık',
      '$icon $title — sıra sende!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'habits_chain',
          'Zincir hatırlatıcı',
          channelDescription: 'Bir alışkanlık tamamlanınca tetiklenen hatırlatıcılar',
          importance: Importance.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
    );
  }

  // tz.local hiç ayarlanmadığı için UTC'dir. Saat bu yüzden cihazın yerel
  // DateTime'ı ile hesaplanıp aynı ana karşılık gelen TZDateTime'a çevrilir.
  // ponytail: yaz saati geçişinde bildirim 1 saat kayabilir; gerekirse
  // flutter_timezone ile tz.setLocalLocation yapılmalı.
  static tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = DateTime(now.year, now.month, now.day + 1, hour, minute);
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }

  static tz.TZDateTime _nextSunday(int hour, int minute) {
    final now = DateTime.now();
    final daysUntilSunday = DateTime.sunday - now.weekday;
    var scheduled = DateTime(now.year, now.month, now.day + daysUntilSunday, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = DateTime(now.year, now.month, now.day + daysUntilSunday + 7, hour, minute);
    }
    return tz.TZDateTime.from(scheduled, tz.local);
  }
}
