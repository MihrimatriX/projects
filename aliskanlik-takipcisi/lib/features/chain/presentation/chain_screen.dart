import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_header.dart';
import '../../habits/models/habit.dart';
import '../../habits/presentation/habit_form_dialog.dart';
import '../../habits/providers/habits_provider.dart';
import '../../home/chain_helpers.dart';
import '../../shell/app_shell.dart';
import '../chain_groups.dart';

class ChainScreen extends ConsumerWidget {
  const ChainScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsProvider);

    return Scaffold(
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (habits) {
          final chains = buildChainGroups(habits);

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              AppHeader(
                title: 'Zincir Alışkanlıklar',
                subtitle: chains.isEmpty
                    ? 'Henüz zincir yok'
                    : 'Tetikleyici sırası · ${chains.length} zincir aktif',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppColors.contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (chains.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(AppColors.radiusCard),
                          border: Border.all(color: AppTheme.border(context)),
                        ),
                        child: Text(
                          'Alışkanlık eklerken "Tetikleyici alışkanlık" seçerek zincir oluşturabilirsiniz.',
                          style: TextStyle(color: AppTheme.muted(context), height: 1.5),
                        ),
                      )
                    else
                      for (final chain in chains) ...[
                        _ChainBlock(
                          chain: chain,
                          onToggle: (id) => handleHabitToggle(context, ref, id),
                        ),
                        const SizedBox(height: 20),
                      ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(AppColors.radiusInput),
                      ),
                      child: Text(
                        'Zincir alışkanlıklar bir adım tamamlandığında sonrakini tetikler. '
                        'Gamification yok — sadece sıralı check-in akışı.',
                        style: TextStyle(fontSize: 13, color: AppTheme.muted(context), height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: AppFab(
        tooltip: 'Yeni alışkanlık',
        onPressed: () {
          final habits = ref.read(habitsProvider).value ?? [];
          _addHabit(context, ref, habits);
        },
      ),
    );
  }
}

class _ChainBlock extends StatelessWidget {
  const _ChainBlock({required this.chain, required this.onToggle});

  final ChainGroup chain;
  final ValueChanged<String> onToggle;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(chain.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < chain.steps.length; i++) ...[
                if (i > 0)
                  _ChainConnector(
                    done: chain.steps[i - 1].doneToday,
                  ),
                Expanded(
                  child: _ChainNode(
                    habit: chain.steps[i],
                    status: chainNodeStatus(chain.steps[i], chain.steps),
                    onTap: () => onToggle(chain.steps[i].id),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ChainConnector extends StatelessWidget {
  const _ChainConnector({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Center(
        child: Container(
          height: 2,
          color: done
              ? AppColors.success
              : AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _ChainNode extends StatelessWidget {
  const _ChainNode({
    required this.habit,
    required this.status,
    required this.onTap,
  });

  final Habit habit;
  final ChainNodeStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDone = status == ChainNodeStatus.done;
    final isPending = status == ChainNodeStatus.pending;

    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(
              color: isDone
                  ? AppColors.success
                  : isPending
                      ? AppColors.warning
                      : AppTheme.border(context),
              style: isPending ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(habit.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 8),
                Text(
                  habit.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  chainNodeStatusLabel(status),
                  style: TextStyle(fontSize: 11, color: AppTheme.muted(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
