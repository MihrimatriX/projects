import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';

import '../features/habits/models/habit.dart';

abstract final class HomeWidgetService {
  static const _androidProvider = 'com.example.aliskanlik_takipcisi.HabitWidgetProvider';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<void> init() async {
    if (!supported) return;
    await HomeWidget.setAppGroupId('group.aliskanlik.takipcisi');
  }

  static Future<void> sync(List<Habit> habits) async {
    if (!supported) return;

    final done = habits.where((h) => h.doneToday).length;
    final total = habits.length;
    final best = habits.isEmpty ? 0 : habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);
    final next = habits.where((h) => !h.doneToday).cast<Habit?>().firstOrNull;

    await HomeWidget.saveWidgetData<int>('done_count', done);
    await HomeWidget.saveWidgetData<int>('total_count', total);
    await HomeWidget.saveWidgetData<int>('best_streak', best);
    await HomeWidget.saveWidgetData<String>('next_habit', next?.title ?? '');
    await HomeWidget.saveWidgetData<String>('next_icon', next?.icon ?? '🌱');

    await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
  }
}
