import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_header.dart';
import '../../habits/models/habit.dart';
import '../../habits/providers/habits_provider.dart';
import '../widgets/heatmap_grid.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _selectedKey = AppDates.todayKey();
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final heatmap = ref.watch(heatmapDataProvider);
    const days = 90;
    final keys = AppDates.lastNDays(days);

    return Scaffold(
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(child: Text('Henüz veri yok'));
          }

          final activeDays = keys.where((k) => (heatmap[k] ?? 0) > 0).length;
          final emptyDays = days - activeDays;
          final rate = (activeDays / days * 100).round();
          final selectedKey = _selectedKey ?? AppDates.todayKey();
          final selectedDate = AppDates.parseKey(selectedKey);
          final doneOnDay = habits.where((h) => h.completionDates.contains(selectedKey)).length;
          final leaders = [...habits]..sort((a, b) => b.streak.compareTo(a.streak));

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 768;
              final main = _HeatmapMain(
                habits: habits,
                heatmap: heatmap,
                days: days,
                rate: rate,
                activeDays: activeDays,
                emptyDays: emptyDays,
                selectedKey: selectedKey,
                onDaySelected: (key) => setState(() => _selectedKey = key),
              );
              final sidebar = _StatsSidebar(
                selectedDate: selectedDate,
                doneOnDay: doneOnDay,
                total: habits.length,
                habits: habits,
                selectedKey: selectedKey,
                leaders: leaders.take(3).toList(),
                onToggleHabit: (id) =>
                    ref.read(habitsProvider.notifier).toggleOn(id, selectedKey),
              );

              return ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  AppHeader(
                    title: 'Isı Haritası',
                    subtitle: 'Son $days gün · ${habits.length} alışkanlık · çevrimdışı',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppColors.contentPadding),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: main),
                              const SizedBox(width: AppColors.sectionGap),
                              SizedBox(width: 280, child: sidebar),
                            ],
                          )
                        : Column(
                            children: [
                              main,
                              const SizedBox(height: AppColors.sectionGap),
                              sidebar,
                            ],
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HeatmapMain extends StatelessWidget {
  const _HeatmapMain({
    required this.habits,
    required this.heatmap,
    required this.days,
    required this.rate,
    required this.activeDays,
    required this.emptyDays,
    required this.selectedKey,
    required this.onDaySelected,
  });

  final List<Habit> habits;
  final Map<String, int> heatmap;
  final int days;
  final int rate;
  final int activeDays;
  final int emptyDays;
  final String selectedKey;
  final ValueChanged<String> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompletionHero(rate: rate, activeDays: activeDays, days: days),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _StatPill(value: '$activeDays', label: 'Aktif gün')),
            const SizedBox(width: 12),
            Expanded(child: _StatPill(value: '$emptyDays', label: 'Boş gün')),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Son $days gün',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text('Güne dokun', style: TextStyle(fontSize: 11, color: AppTheme.muted(context))),
                ],
              ),
              const SizedBox(height: 14),
              HeatmapGrid(
                counts: heatmap,
                days: days,
                selectedKey: selectedKey,
                onDaySelected: onDaySelected,
                habitCount: habits.length,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletionHero extends StatelessWidget {
  const _CompletionHero({
    required this.rate,
    required this.activeDays,
    required this.days,
  });

  final int rate;
  final int activeDays;
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppColors.contentPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '%$rate',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.03,
                        color: AppColors.heatmap3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tamamlama oranı',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$activeDays / $days gün',
                style: TextStyle(fontSize: 12, color: AppTheme.muted(context)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 8,
              backgroundColor: AppColors.heatmap0,
              color: AppColors.heatmap3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.02),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.muted(context))),
        ],
      ),
    );
  }
}

class _StatsSidebar extends StatelessWidget {
  const _StatsSidebar({
    required this.selectedDate,
    required this.doneOnDay,
    required this.total,
    required this.habits,
    required this.selectedKey,
    required this.leaders,
    this.onToggleHabit,
  });

  final DateTime selectedDate;
  final int doneOnDay;
  final int total;
  final List<Habit> habits;
  final String selectedKey;
  final List<Habit> leaders;
  /// Seçili günde alışkanlığın kaydını açar/kapatır (geçmiş gün düzeltme).
  final ValueChanged<String>? onToggleHabit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppDates.formatShort(selectedDate).toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.06,
                  color: AppTheme.muted(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$doneOnDay / $total tamamlandı',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.02),
              ),
              if (onToggleHabit != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Unutulan günü işaretlemek için alışkanlığa dokunun',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted(context)),
                  ),
                ),
              const SizedBox(height: 14),
              for (final h in habits)
                _DayInspectorItem(
                  habit: h,
                  done: h.completionDates.contains(selectedKey),
                  onTap: onToggleHabit == null ? null : () => onToggleHabit!(h.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final h in leaders) ...[
          _StreakLeader(habit: h),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DayInspectorItem extends StatelessWidget {
  const _DayInspectorItem({required this.habit, required this.done, this.onTap});

  final Habit habit;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppColors.radiusInput);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: done ? AppTheme.successBg(context) : Theme.of(context).scaffoldBackgroundColor,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _row(context),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context) {
    return Row(
        children: [
          Text(habit.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(habit.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(
            done ? 'TAMAM' : 'EKSİK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.06,
              color: done ? AppColors.success : AppTheme.muted(context),
            ),
          ),
        ],
    );
  }
}

class _StreakLeader extends StatelessWidget {
  const _StreakLeader({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(habit.icon, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Aktif seri', style: TextStyle(fontSize: 12, color: AppTheme.muted(context))),
              ],
            ),
          ),
          Text(
            '${habit.streak}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.02,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
