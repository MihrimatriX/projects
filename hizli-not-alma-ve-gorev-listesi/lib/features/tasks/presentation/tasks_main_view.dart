import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/prefs_provider.dart';
import '../../../core/task_filters.dart';
import '../../../core/task_groups.dart';
import '../../../core/theme/app_colors.dart';
import '../../projects/providers/projects_provider.dart';
import '../../tags/providers/tags_provider.dart';
import '../models/task_item.dart';
import '../providers/task_view_provider.dart';
import '../providers/tasks_provider.dart';
import 'calendar_view.dart';
import '../widgets/quick_add_bar.dart';
import '../widgets/task_detail_sheet.dart';
import '../widgets/task_row.dart';

class TasksMainView extends ConsumerWidget {
  const TasksMainView({
    super.key,
    this.quickAddFocus,
    this.selectedTaskId,
    this.onSelectTask,
    this.animDuration = const Duration(milliseconds: 150),
    this.useInlineDetail = false,
  });

  final FocusNode? quickAddFocus;
  final String? selectedTaskId;
  final ValueChanged<TaskItem>? onSelectTask;
  final Duration animDuration;
  final bool useInlineDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(taskViewProvider);
    final brightness = Theme.of(context).brightness;
    final isMobile = MediaQuery.sizeOf(context).width < AppLayout.breakpointDrawer;

    if (view.kind == TaskViewKind.calendar) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(AppLayout.pagePaddingV, 16, AppLayout.pagePaddingV, 16),
        child: CalendarView(),
      );
    }

    final tasksAsync = ref.watch(filteredTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? [];
    final tags = ref.watch(tagsProvider).value ?? [];
    final search = ref.watch(searchQueryProvider);

    var title = view.title;
    var eyebrow = view.title;
    if (view.kind == TaskViewKind.project && view.projectId != null) {
      final match = projects.where((p) => p.id == view.projectId);
      title = match.isEmpty ? 'Proje' : match.first.name;
      eyebrow = 'Proje';
    } else if (view.kind == TaskViewKind.tag && view.tagId != null) {
      final match = tags.where((t) => t.id == view.tagId);
      title = match.isEmpty ? 'Etiket' : match.first.display;
      eyebrow = 'Etiket';
    } else if (view.kind == TaskViewKind.today) {
      eyebrow = DateFormat.yMMMMd('tr_TR').format(DateTime.now());
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 14 : AppLayout.pagePaddingV,
        isMobile ? 12 : 16,
        isMobile ? 14 : AppLayout.pagePaddingV,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHead(
            eyebrow: eyebrow,
            title: title,
            openCount: tasksAsync.value == null ? 0 : countOpen(tasksAsync.value!),
            overdueCount: tasksAsync.value == null ? 0 : countOverdue(tasksAsync.value!),
          ),
          const SizedBox(height: 18),
          QuickAddBar(
            focusNode: quickAddFocus,
            onSubmit: (t) => ref.read(tasksProvider.notifier).add(t),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return Center(
                    child: Text(
                      search.isNotEmpty ? 'Eşleşme bulunamadı\nAramayı temizleyin ya da yeni bir görev ekleyin.' : _emptyMessage(view),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.secondaryTextFor(brightness)),
                    ),
                  );
                }

                final groups = groupTasks(tasks, view);
                return Semantics(
                  liveRegion: true,
                  label: '${tasks.length} görev',
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final group in groups) ...[
                        if (group.title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
                            child: Text(
                              group.title.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.08 * 12,
                                color: AppColors.secondaryTextFor(brightness),
                              ),
                            ),
                          ),
                        ...group.tasks.map(
                          (task) => TaskRow(
                            task: task,
                            selected: selectedTaskId == task.id,
                            animDuration: animDuration,
                            onToggle: () => ref.read(tasksProvider.notifier).toggle(task.id),
                            onTap: () {
                              onSelectTask?.call(task);
                              if (!useInlineDetail) {
                                showTaskDetailSheet(context, ref, task);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _emptyMessage(TaskView view) => switch (view.kind) {
        TaskViewKind.today => 'Bugün için görev yok 🎉\nYukarıdan hızlı ekleme ile başlayın.',
        TaskViewKind.inbox => 'Gelen kutun boş.\n+ Görev ekle veya #etiket @bağlam kullan.',
        TaskViewKind.upcoming => 'Yaklaşan görev yok.',
        TaskViewKind.all => 'Henüz görev yok.',
        TaskViewKind.project => 'Bu projede görev yok.\nHızlı ekleme ile ilk görevi oluştur.',
        TaskViewKind.tag => 'Bu etikette görev yok.',
        TaskViewKind.calendar => '',
      };
}

class _PageHead extends StatelessWidget {
  const _PageHead({
    required this.eyebrow,
    required this.title,
    required this.openCount,
    required this.overdueCount,
  });

  final String eyebrow;
  final String title;
  final int openCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.08 * 12,
                  color: AppColors.secondaryTextFor(brightness),
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.01 * 22,
                  color: AppColors.primaryTextFor(brightness),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          children: [
            _MetaPill(label: '$openCount açık görev'),
            _MetaPill(label: '$overdueCount geciken'),
          ],
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cardFor(brightness),
        border: Border.all(color: AppColors.borderFor(brightness)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: AppColors.secondaryTextFor(brightness)),
      ),
    );
  }
}
