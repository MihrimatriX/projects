import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_header.dart';
import '../chain_helpers.dart';
import '../../habits/models/habit.dart';
import '../../habits/presentation/habit_form_dialog.dart';
import '../../habits/providers/habits_provider.dart';
import '../../shell/app_shell.dart';
import '../widgets/habit_card.dart';
import '../widgets/streak_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _addHabit(BuildContext context, WidgetRef ref, List<Habit> habits) async {
    final result = await HabitFormDialog.show(context, allHabits: habits);
    if (result == null) return;
    await ref.read(habitsProvider.notifier).add(
          title: result.title,
          icon: result.icon,
          color: result.color,
          frequency: result.frequency,
          flexStreakEnabled: result.flexStreakEnabled,
          flexTargetPerWeek: result.flexTargetPerWeek,
          chainFromId: result.chainFromId,
        );
  }

  Future<void> _editHabit(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    List<Habit> habits,
  ) async {
    final result = await HabitFormDialog.show(context, habit: habit, allHabits: habits);
    if (result == null) return;
    await ref.read(habitsProvider.notifier).updateHabit(
          habit.copyWith(
            title: result.title,
            icon: result.icon,
            color: result.color,
            frequency: result.frequency,
            flexStreakEnabled: result.flexStreakEnabled,
            flexTargetPerWeek: result.flexTargetPerWeek,
            chainFromId: result.chainFromId,
            clearChainFromId: result.chainFromId == null,
          ),
        );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Habit habit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alışkanlığı sil'),
        content: Text('"${habit.title}" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(habitsProvider.notifier).remove(habit.id);
  }

  void _showHabitActions(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
    List<Habit> habits,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Düzenle'),
              onTap: () {
                Navigator.pop(ctx);
                _editHabit(context, ref, habit, habits);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Sil', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ref, habit);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);
    final bestStreak = ref.watch(bestStreakProvider);
    final topHabit = ref.watch(topStreakHabitProvider);
    final flexHabit = ref.watch(bestFlexHabitProvider);
    final today = DateTime.now();

    return Scaffold(
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (habits) {
          final count = habits.length;
          final doneToday = habits.where((h) => h.doneToday).length;
          final allDone = count > 0 && doneToday == count;

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              AppHeader(
                title: 'Bugün',
                subtitle: AppDates.formatHeader(today),
                trailing: IconButton(
                  icon: Icon(Icons.settings_outlined, color: AppTheme.muted(context)),
                  tooltip: 'Ayarlar',
                  onPressed: () => context.go('/settings'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppColors.contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (allDone)
                      Container(
                        margin: const EdgeInsets.only(bottom: AppColors.sectionGap),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.successBg(context),
                          borderRadius: BorderRadius.circular(AppColors.radiusInput),
                        ),
                        child: const Text(
                          'Bugünkü alışkanlıklar tamamlandı',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    if (count > 0) ...[
                      StreakCard(streak: bestStreak, topHabit: topHabit, flexHabit: flexHabit),
                      const SizedBox(height: AppColors.sectionGap),
                    ],
                    if (count == 0)
                      _EmptyState(onAdd: () => _addHabit(context, ref, habits))
                    else ...[
                      Text(
                        'Check-in',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 12),
                      for (final h in habits)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: HabitCard(
                            habit: h,
                            onToggle: () => handleHabitToggle(context, ref, h.id),
                            onLongPress: () => _showHabitActions(context, ref, h, habits),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: AppFab(
        onPressed: () {
          final habits = ref.read(habitsProvider).value ?? [];
          _addHabit(context, ref, habits);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Henüz alışkanlık yok'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('İlk alışkanlığı ekle'),
          ),
        ],
      ),
    );
  }
}
