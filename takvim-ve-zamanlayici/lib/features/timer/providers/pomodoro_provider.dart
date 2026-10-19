import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notification_service.dart';
import '../../../core/time_blocking.dart';
import '../../events/providers/events_provider.dart';

enum PomodoroPhase { focus, shortBreak, longBreak }

class PomodoroSettings {
  const PomodoroSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoTimeBlock = false,
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoTimeBlock;

  PomodoroSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
    bool? autoTimeBlock,
  }) {
    return PomodoroSettings(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      sessionsBeforeLongBreak:
          sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
      autoTimeBlock: autoTimeBlock ?? this.autoTimeBlock,
    );
  }

  Map<String, dynamic> toJson() => {
        'focusMinutes': focusMinutes,
        'shortBreakMinutes': shortBreakMinutes,
        'longBreakMinutes': longBreakMinutes,
        'sessionsBeforeLongBreak': sessionsBeforeLongBreak,
        'autoTimeBlock': autoTimeBlock,
      };

  factory PomodoroSettings.fromJson(Map<String, dynamic> json) {
    return PomodoroSettings(
      focusMinutes: json['focusMinutes'] as int? ?? 25,
      shortBreakMinutes: json['shortBreakMinutes'] as int? ?? 5,
      longBreakMinutes: json['longBreakMinutes'] as int? ?? 15,
      sessionsBeforeLongBreak: json['sessionsBeforeLongBreak'] as int? ?? 4,
      autoTimeBlock: json['autoTimeBlock'] as bool? ?? false,
    );
  }
}

class PomodoroState {
  const PomodoroState({
    required this.phase,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.running,
    required this.completedSessions,
    required this.settings,
    this.focusStartedAt,
  });

  final PomodoroPhase phase;
  final int remainingSeconds;
  final int totalSeconds;
  final bool running;
  final int completedSessions;
  final PomodoroSettings settings;
  final DateTime? focusStartedAt;

  double get progress =>
      totalSeconds == 0 ? 0 : 1 - (remainingSeconds / totalSeconds);

  String get phaseLabel => switch (phase) {
        PomodoroPhase.focus => 'Odak',
        PomodoroPhase.shortBreak => 'Kısa mola',
        PomodoroPhase.longBreak => 'Uzun mola',
      };

  PomodoroState copyWith({
    PomodoroPhase? phase,
    int? remainingSeconds,
    int? totalSeconds,
    bool? running,
    int? completedSessions,
    PomodoroSettings? settings,
    DateTime? focusStartedAt,
    bool clearFocusStartedAt = false,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      running: running ?? this.running,
      completedSessions: completedSessions ?? this.completedSessions,
      settings: settings ?? this.settings,
      focusStartedAt:
          clearFocusStartedAt ? null : (focusStartedAt ?? this.focusStartedAt),
    );
  }
}

final pomodoroProvider =
    NotifierProvider<PomodoroNotifier, PomodoroState>(PomodoroNotifier.new);

class PomodoroNotifier extends Notifier<PomodoroState> {
  static const _settingsKey = 'pomodoro_settings';
  Timer? _timer;
  bool _settingsLoaded = false;

  @override
  PomodoroState build() {
    ref.onDispose(() => _timer?.cancel());
    _loadSettingsOnce();
    const settings = PomodoroSettings();
    final seconds = settings.focusMinutes * 60;
    return PomodoroState(
      phase: PomodoroPhase.focus,
      remainingSeconds: seconds,
      totalSeconds: seconds,
      running: false,
      completedSessions: 0,
      settings: settings,
    );
  }

  Future<void> _loadSettingsOnce() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return;
    try {
      final settings =
          PomodoroSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _resetPhase(PomodoroPhase.focus, settings: settings);
    } catch (_) {}
  }

  Future<void> updateSettings(PomodoroSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    _resetPhase(state.phase, settings: settings);
  }

  void start() {
    if (state.running) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    final focusStart = state.phase == PomodoroPhase.focus && state.focusStartedAt == null
        ? DateTime.now()
        : state.focusStartedAt;
    state = state.copyWith(running: true, focusStartedAt: focusStart);
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(running: false);
  }

  void reset() {
    _timer?.cancel();
    _resetPhase(PomodoroPhase.focus);
  }

  void skip() {
    _timer?.cancel();
    _advancePhase();
  }

  Future<void> createFocusBlockNow() async {
    final block = createScheduledFocusBlock(
      start: DateTime.now(),
      focusMinutes: state.settings.focusMinutes,
    );
    await ref.read(eventsProvider.notifier).add(block);
  }

  void _tick() {
    if (state.remainingSeconds <= 1) {
      // _advancePhase async (bildirim + takvime blok ekleme); sayaç durmazsa
      // her saniye tekrar çağrılıp seans/blok çift sayılıyordu.
      _timer?.cancel();
      _advancePhase();
      return;
    }
    state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
  }

  Future<void> _advancePhase() async {
    final completedPhase = state.phase;
    await NotificationService.showPomodoroComplete(completedPhase);

    if (completedPhase == PomodoroPhase.focus) {
      if (state.settings.autoTimeBlock && state.focusStartedAt != null) {
        final duration = DateTime.now().difference(state.focusStartedAt!);
        if (duration.inMinutes >= 1) {
          final block = createFocusBlock(
            start: state.focusStartedAt!,
            duration: duration,
          );
          await ref.read(eventsProvider.notifier).add(block);
        }
      }
      final sessions = state.completedSessions + 1;
      final longBreak = sessions % state.settings.sessionsBeforeLongBreak == 0;
      _resetPhase(
        longBreak ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak,
        completedSessions: sessions,
        autoStart: true,
      );
    } else {
      _resetPhase(PomodoroPhase.focus, autoStart: true);
    }
  }

  void _resetPhase(
    PomodoroPhase phase, {
    PomodoroSettings? settings,
    int? completedSessions,
    bool autoStart = false,
  }) {
    _timer?.cancel(); // running=false olurken arka planda sayaç kalmasın (ör. ayar değişimi)
    final s = settings ?? state.settings;
    final seconds = switch (phase) {
      PomodoroPhase.focus => s.focusMinutes * 60,
      PomodoroPhase.shortBreak => s.shortBreakMinutes * 60,
      PomodoroPhase.longBreak => s.longBreakMinutes * 60,
    };
    state = PomodoroState(
      phase: phase,
      remainingSeconds: seconds,
      totalSeconds: seconds,
      running: false,
      completedSessions: completedSessions ?? state.completedSessions,
      settings: s,
      focusStartedAt: phase == PomodoroPhase.focus && autoStart ? DateTime.now() : null,
    );
    if (autoStart) start();
  }
}

String formatPomodoroTime(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
