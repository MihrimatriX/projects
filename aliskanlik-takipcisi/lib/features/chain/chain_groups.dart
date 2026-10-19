import '../habits/models/habit.dart';

class ChainGroup {
  const ChainGroup({required this.title, required this.steps});

  final String title;
  final List<Habit> steps;
}

List<ChainGroup> buildChainGroups(List<Habit> habits) {
  if (habits.isEmpty) return const [];

  final referenced = habits.map((h) => h.chainFromId).whereType<String>().toSet();
  final roots = habits.where((h) => referenced.contains(h.id)).toList()
    ..sort((a, b) => a.title.compareTo(b.title));

  final groups = <ChainGroup>[];
  for (final root in roots) {
    final steps = <Habit>[root];
    var current = root;
    while (true) {
      final next = habits.where((h) => h.chainFromId == current.id).firstOrNull;
      // A→B→A gibi döngüsel zincirde sonsuz döngüye girmemek için.
      if (next == null || steps.contains(next)) break;
      steps.add(next);
      current = next;
    }
    if (steps.length < 2) continue;

    final names = steps.map((h) => h.title).join(' → ');
    groups.add(ChainGroup(title: names, steps: steps));
  }

  return groups;
}

enum ChainNodeStatus { done, pending, waiting }

ChainNodeStatus chainNodeStatus(Habit habit, List<Habit> steps) {
  if (habit.doneToday) return ChainNodeStatus.done;

  final index = steps.indexWhere((h) => h.id == habit.id);
  if (index <= 0) return ChainNodeStatus.waiting;

  final previousDone = steps[index - 1].doneToday;
  return previousDone ? ChainNodeStatus.pending : ChainNodeStatus.waiting;
}

String chainNodeStatusLabel(ChainNodeStatus status) => switch (status) {
      ChainNodeStatus.done => 'Tamamlandı',
      ChainNodeStatus.pending => 'Bekliyor',
      ChainNodeStatus.waiting => 'Sıradaki',
    };
