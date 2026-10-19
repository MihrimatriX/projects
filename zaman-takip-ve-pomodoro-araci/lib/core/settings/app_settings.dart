import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettings {
  const AppSettings({
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.longBreakMinutes = 15,
    this.goalHours = 6,
  });

  final int workMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int goalHours;

  AppSettings copyWith({
    int? workMinutes,
    int? breakMinutes,
    int? longBreakMinutes,
    int? goalHours,
  }) =>
      AppSettings(
        workMinutes: workMinutes ?? this.workMinutes,
        breakMinutes: breakMinutes ?? this.breakMinutes,
        longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
        goalHours: goalHours ?? this.goalHours,
      );
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _kWork = 'work_min';
  static const _kBreak = 'break_min';
  static const _kLongBreak = 'long_break_min';
  static const _kGoal = 'goal_hours';

  late SharedPreferences _prefs;

  @override
  AppSettings build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      workMinutes: _prefs.getInt(_kWork) ?? 25,
      breakMinutes: _prefs.getInt(_kBreak) ?? 5,
      longBreakMinutes: _prefs.getInt(_kLongBreak) ?? 15,
      goalHours: _prefs.getInt(_kGoal) ?? 6,
    );
  }

  Future<void> setWorkMinutes(int v) async {
    await _prefs.setInt(_kWork, v);
    state = state.copyWith(workMinutes: v);
  }

  Future<void> setBreakMinutes(int v) async {
    await _prefs.setInt(_kBreak, v);
    state = state.copyWith(breakMinutes: v);
  }

  Future<void> setLongBreakMinutes(int v) async {
    await _prefs.setInt(_kLongBreak, v);
    state = state.copyWith(longBreakMinutes: v);
  }

  Future<void> setGoalHours(int v) async {
    await _prefs.setInt(_kGoal, v);
    state = state.copyWith(goalHours: v);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('main.dart içinde override edilmeli');
});
