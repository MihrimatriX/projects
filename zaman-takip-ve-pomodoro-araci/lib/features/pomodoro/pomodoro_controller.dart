import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings/app_settings.dart';

String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Pomodoro durumu. Çalışırken kalan süre tutulmaz, sabit bitiş anından ([endAt])
/// duvar saatine göre hesaplanır: kare hızı, Timer gecikmesi, küçültülmüş pencere
/// ya da bilgisayarın uykuya geçmesi sayacı geride bırakmaz.
class PomodoroState {
  const PomodoroState({
    this.work = true,
    this.phase = 1,
    this.remaining = 25 * 60,
    this.total = 25 * 60,
    this.endAt,
    this.tomatoes = 0,
    this.tomatoesDay = '',
  });

  final bool work;

  /// 1..4; 4. odaktan sonra uzun mola.
  final int phase;

  /// Duraklatılmış/hazır iken kalan saniye.
  final int remaining;
  final int total;

  /// null değilse çalışıyor.
  final DateTime? endAt;
  final int tomatoes;
  final String tomatoesDay;

  bool get running => endAt != null;

  int remainingAt(DateTime now) => endAt == null
      ? remaining
      : math.max(0, (endAt!.difference(now).inMilliseconds / 1000).ceil());

  int tomatoesOn(DateTime now) => tomatoesDay == _dayKey(now) ? tomatoes : 0;

  static int durationFor(bool work, int phase, AppSettings s) =>
      (work ? s.workMinutes : (phase >= 4 ? s.longBreakMinutes : s.breakMinutes)) * 60;

  PomodoroState _copy({
    bool? work,
    int? phase,
    int? remaining,
    int? total,
    DateTime? endAt,
    bool clearEnd = false,
    int? tomatoes,
    String? tomatoesDay,
  }) =>
      PomodoroState(
        work: work ?? this.work,
        phase: phase ?? this.phase,
        remaining: remaining ?? this.remaining,
        total: total ?? this.total,
        endAt: clearEnd ? null : (endAt ?? this.endAt),
        tomatoes: tomatoes ?? this.tomatoes,
        tomatoesDay: tomatoesDay ?? this.tomatoesDay,
      );

  PomodoroState start(DateTime now) =>
      running ? this : _copy(endAt: now.add(Duration(seconds: remaining)));

  PomodoroState pause(DateTime now) =>
      running ? _copy(remaining: remainingAt(now), clearEnd: true) : this;

  /// Bitiş anı geçtiyse fazı tamamlar; değilse aynı nesneyi döner.
  PomodoroState tick(DateTime now, AppSettings s) =>
      running && remainingAt(now) <= 0 ? complete(now, s) : this;

  /// Fazı bitirir ve bir sonrakine hazır (duraklatılmış) geçer. Odak tamamlanırsa
  /// domates bitiş gününe yazılır; [skipped] ise sayılmaz.
  PomodoroState complete(DateTime now, AppSettings s, {bool skipped = false}) {
    var t = tomatoesOn(now);
    if (work && !skipped && _dayKey(endAt ?? now) == _dayKey(now)) t++;
    // 4. odaktan sonra uzun mola; faz mola bitince 1'e döner.
    final nextWork = !work;
    final nextPhase = work ? phase : (phase >= 4 ? 1 : phase + 1);
    final secs = durationFor(nextWork, nextPhase, s);
    return PomodoroState(
      work: nextWork,
      phase: nextPhase,
      remaining: secs,
      total: secs,
      tomatoes: t,
      tomatoesDay: _dayKey(now),
    );
  }

  /// Ayar değişince hazır/duraklatılmış fazın süresi güncellenir.
  PomodoroState withSettings(AppSettings s) {
    if (running) return this;
    final secs = durationFor(work, phase, s);
    return secs == total ? this : _copy(remaining: secs, total: secs);
  }

  Map<String, dynamic> toJson() => {
        'work': work,
        'phase': phase,
        'remaining': remaining,
        'total': total,
        if (endAt != null) 'endAt': endAt!.millisecondsSinceEpoch,
        'tomatoes': tomatoes,
        'tomatoesDay': tomatoesDay,
      };

  factory PomodoroState.fromJson(Map<String, dynamic> j) => PomodoroState(
        work: j['work'] as bool? ?? true,
        phase: ((j['phase'] as int?) ?? 1).clamp(1, 4),
        remaining: j['remaining'] as int? ?? 25 * 60,
        total: j['total'] as int? ?? 25 * 60,
        endAt: j['endAt'] is int ? DateTime.fromMillisecondsSinceEpoch(j['endAt'] as int) : null,
        tomatoes: j['tomatoes'] as int? ?? 0,
        tomatoesDay: j['tomatoesDay'] as String? ?? '',
      );
}

/// Ekrandan bağımsız yaşar: sekme değiştirmek çalışan Pomodoro'yu durdurmaz.
/// Durum her geçişte SharedPreferences'a yazılır; uygulama kapanıp açılınca
/// kaldığı yerden (çalışıyorsa bitiş anına göre) devam eder.
final pomodoroProvider = NotifierProvider<PomodoroNotifier, PomodoroState>(PomodoroNotifier.new);

class PomodoroNotifier extends Notifier<PomodoroState> {
  static const storageKey = 'pomodoro_state';
  Timer? _timer;

  /// Testlerde sahte saat için değiştirilebilir.
  DateTime Function() clock = DateTime.now;

  @override
  PomodoroState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    ref.onDispose(() => _timer?.cancel());
    ref.listen(settingsProvider, (_, s) => _set(state.withSettings(s)));
    var initial = PomodoroState(
      remaining: PomodoroState.durationFor(true, 1, ref.read(settingsProvider)),
      total: PomodoroState.durationFor(true, 1, ref.read(settingsProvider)),
    );
    final raw = prefs.getString(storageKey);
    if (raw != null) {
      try {
        initial = PomodoroState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // bozuk kayıt: varsayılanla başla
      }
    }
    initial = initial.withSettings(ref.read(settingsProvider));
    _syncTimer(initial);
    return initial;
  }

  void _set(PomodoroState next) {
    if (identical(next, state)) return;
    state = next;
    _syncTimer(next);
    ref.read(sharedPreferencesProvider).setString(storageKey, jsonEncode(next.toJson()));
  }

  void _syncTimer(PomodoroState s) {
    if (!s.running) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }

  /// Saniyelik tik: yalnızca ekran yenilemesi ve bitiş kontrolü içindir; süre
  /// hesabı her zaman [PomodoroState.endAt]'ten yapılır.
  void tick() {
    final next = state.tick(clock(), ref.read(settingsProvider));
    if (!identical(next, state)) {
      // Faz kendiliğinden bitti: pencere arkadayken de fark edilsin.
      SystemSound.play(SystemSoundType.alert);
      _set(next);
    } else if (state.running) {
      // Kalan süre görünümü için yeniden çizim (durum aynı, yeni nesne gerekmez).
      ref.notifyListeners();
    }
  }

  void start() => _set(state.start(clock()));
  void pause() => _set(state.pause(clock()));
  void toggle() => state.running ? pause() : start();
  void skip() => _set(state.complete(clock(), ref.read(settingsProvider), skipped: true));
}
