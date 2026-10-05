import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/home_widget_service.dart';
import '../data/habits_repository.dart';
import '../models/habit.dart';

final habitsRepositoryProvider = Provider((ref) => HabitsRepository());

/// Şimdiki zaman kaynağı; testlerde sabit bir güne geçersiz kılınır.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final habitsProvider =
    AsyncNotifierProvider<HabitsNotifier, List<Habit>>(HabitsNotifier.new);

// Tüm alışkanlık listesi tek bir AsyncNotifier'da tutulur; her değişiklik
// _persist ile önce SharedPreferences'a yazılır, sonra state ve Android widget'ı güncellenir.
class HabitsNotifier extends AsyncNotifier<List<Habit>> {
  HabitsRepository get _repo => ref.read(habitsRepositoryProvider);
  DateTime _now() => ref.read(clockProvider)();

  String? _loadedDay;

  @override
  Future<List<Habit>> build() async {
    final habits = await _repo.load(now: _now());
    _loadedDay = AppDates.todayKey(_now());

    // Uygulama gece yarısını açık geçirirse "bugün" işaretleri ve seriler
    // bayatlamasın: gün değişince tarihlerden yeniden hesapla.
    final timer = Timer.periodic(const Duration(minutes: 1), (_) => refreshDay());
    ref.onDispose(timer.cancel);

    await HomeWidgetService.sync(habits);
    return habits;
  }

  /// Gün değiştiyse doneToday/seri alanlarını yeniden hesaplar.
  Future<void> refreshDay() async {
    final current = state.value;
    final today = AppDates.todayKey(_now());
    if (current == null || today == _loadedDay) return;
    _loadedDay = today;
    await _persist(current);
  }

  Future<void> add({
    required String title,
    String icon = '🌱',
    int color = 0xFF6366F1,
    HabitFrequency frequency = HabitFrequency.daily,
    bool flexStreakEnabled = false,
    int flexTargetPerWeek = 5,
    String? chainFromId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? [];
    final habit = Habit(
      id: _newId(current),
      title: trimmed,
      icon: icon,
      color: color,
      frequency: frequency,
      flexStreakEnabled: flexStreakEnabled,
      flexTargetPerWeek: flexTargetPerWeek,
      chainFromId: chainFromId,
    );
    await _persist([...current, habit]);
  }

  String _newId(List<Habit> current) {
    var id = DateTime.now().microsecondsSinceEpoch;
    while (current.any((h) => h.id == '$id')) {
      id++;
    }
    return '$id';
  }

  Future<void> updateHabit(Habit updated) async {
    final current = state.value ?? [];
    await _persist(current.map((h) => h.id == updated.id ? updated : h).toList());
  }

  /// Bugünün check-in'ini açar/kapatır.
  Future<ToggleResult> toggle(String id) => toggleOn(id, AppDates.todayKey(_now()));

  /// [dateKey] gününün kaydını açar/kapatır; geçmişte unutulan bir günü
  /// sonradan işaretlemek için de kullanılır. Gelecek günler reddedilir.
  Future<ToggleResult> toggleOn(String id, String dateKey) async {
    final today = AppDates.todayKey(_now());
    if (!AppDates.isValidKey(dateKey) || dateKey.compareTo(today) > 0) {
      return const ToggleResult();
    }
    final current = state.value ?? [];
    var completedNow = false;

    final updated = current.map((h) {
      if (h.id != id) return h;
      final dates = {...h.completionDates};
      if (!dates.remove(dateKey)) {
        dates.add(dateKey);
        completedNow = true;
      }
      final sorted = dates.toList()..sort();
      return h.copyWith(
        completionDates: sorted,
        lastCompletedDate: sorted.isEmpty ? null : sorted.last,
      );
    }).toList();

    await _persist(updated);

    // Zincir hatırlatıcısı yalnızca bugünkü tamamlamada anlamlı.
    if (!completedNow || dateKey != today) return const ToggleResult();
    final reminders = (state.value ?? [])
        .where((h) => h.chainFromId == id && !h.doneToday)
        .toList();
    return ToggleResult(chainReminders: reminders);
  }

  Future<void> remove(String id) async {
    final current = state.value ?? [];
    final cleaned = current
        .where((h) => h.id != id)
        .map((h) => h.chainFromId == id ? h.copyWith(clearChainFromId: true) : h)
        .toList();
    await _persist(cleaned);
  }

  Future<String> exportJson() async {
    return _repo.exportJson(state.value ?? []);
  }

  String exportCsv() {
    return _repo.exportCsv(state.value ?? []);
  }

  /// JSON yedeğini doğrular ve mevcut listenin yerine koyar. Hatalı veride
  /// FormatException fırlatır ve mevcut veriye dokunmaz. İçe aktarılan
  /// alışkanlık sayısını döner.
  Future<int> importJson(String raw) async {
    final habits = HabitsRepository.decodeHabits(raw.trim());
    final ids = habits.map((h) => h.id).toSet();
    final cleaned = habits
        .map((h) => h.chainFromId != null && !ids.contains(h.chainFromId)
            ? h.copyWith(clearChainFromId: true)
            : h)
        .toList();
    await _persist(cleaned);
    return cleaned.length;
  }

  Future<void> _persist(List<Habit> habits) async {
    final normalized = HabitsRepository.normalize(habits, now: _now());
    await _repo.save(normalized);
    state = AsyncData(normalized);
    await HomeWidgetService.sync(normalized);
  }
}

final heatmapDataProvider = Provider<Map<String, int>>((ref) {
  final habits = ref.watch(habitsProvider).value ?? [];
  final counts = <String, int>{};
  for (final h in habits) {
    for (final date in h.completionDates) {
      counts[date] = (counts[date] ?? 0) + 1;
    }
  }
  return counts;
});

final bestStreakProvider = Provider<int>((ref) {
  final habits = ref.watch(habitsProvider).value ?? [];
  if (habits.isEmpty) return 0;
  return habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);
});

final topStreakHabitProvider = Provider<Habit?>((ref) {
  final habits = ref.watch(habitsProvider).value ?? [];
  if (habits.isEmpty) return null;
  return habits.reduce((a, b) => a.streak >= b.streak ? a : b);
});

final bestFlexHabitProvider = Provider<Habit?>((ref) {
  final habits = ref.watch(habitsProvider).value ?? [];
  final flex = habits.where((h) => h.flexStreakEnabled).toList();
  if (flex.isEmpty) return null;
  flex.sort((a, b) => b.streak.compareTo(a.streak));
  return flex.first;
});
