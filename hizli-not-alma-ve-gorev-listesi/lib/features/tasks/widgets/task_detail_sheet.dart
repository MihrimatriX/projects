import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../projects/providers/projects_provider.dart';
import '../models/repeat_rule.dart';
import '../models/task_item.dart';
import '../providers/tasks_provider.dart';

Future<void> showTaskDetailSheet(BuildContext context, WidgetRef ref, TaskItem task) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => TaskDetailPanel(initial: task, onClose: () => Navigator.pop(ctx)),
  );
}

class TaskDetailPanel extends ConsumerStatefulWidget {
  const TaskDetailPanel({
    super.key,
    required this.initial,
    required this.onClose,
  });

  final TaskItem initial;
  final VoidCallback onClose;

  @override
  ConsumerState<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends ConsumerState<TaskDetailPanel> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _subtaskInput;
  late DateTime? _dueDate;
  late String? _projectId;
  late TaskPriority _priority;
  late RepeatRule _repeat;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _note = TextEditingController(text: widget.initial.note);
    _subtaskInput = TextEditingController();
    _dueDate = widget.initial.dueDate;
    _projectId = widget.initial.projectId;
    _priority = widget.initial.priority;
    _repeat = widget.initial.repeat;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _subtaskInput.dispose();
    super.dispose();
  }

  TaskItem get _current {
    final list = ref.watch(tasksProvider).value ?? [];
    return list.firstWhere((t) => t.id == widget.initial.id, orElse: () => widget.initial);
  }

  Future<void> _save(TaskItem base) async {
    await ref.read(tasksProvider.notifier).saveTask(
          base.copyWith(
            title: _title.text.trim(),
            note: _note.text.trim(),
            dueDate: _dueDate,
            clearDueDate: _dueDate == null,
            projectId: _projectId,
            clearProjectId: _projectId == null,
            priority: _priority,
            repeat: _repeat,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final task = _current;
    final projects = ref.watch(projectsProvider).value ?? [];
    final brightness = Theme.of(context).brightness;
    final isSheet = MediaQuery.sizeOf(context).width < AppLayout.breakpointWide;

    final content = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, isSheet ? MediaQuery.viewInsetsOf(context).bottom + 20 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Görev detayı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primaryTextFor(brightness))),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose),
            ],
          ),
          TextField(
            controller: _title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.primaryTextFor(brightness)),
            decoration: const InputDecoration(labelText: 'Başlık'),
            onChanged: (_) => _save(task),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(_dueDate == null ? 'Son tarih yok' : DateFormat.yMMMMd('tr_TR').format(_dueDate!)),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  // locale: tr verilmez; flutter_localizations olmadan
                  // "No MaterialLocalizations found" hatası verir.
                );
                if (picked != null) {
                  setState(() => _dueDate = picked);
                  await _save(task);
                }
              },
            ),
          ),
          if (_dueDate != null)
            TextButton(
              onPressed: () async {
                setState(() => _dueDate = null);
                await _save(task);
              },
              child: const Text('Son tarihi kaldır'),
            ),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Öncelik'),
            items: const [
              DropdownMenuItem(value: TaskPriority.none, child: Text('Normal')),
              DropdownMenuItem(value: TaskPriority.low, child: Text('Düşük')),
              DropdownMenuItem(value: TaskPriority.high, child: Text('Yüksek')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _priority = v);
              await _save(task);
            },
          ),
          DropdownButtonFormField<RepeatRule>(
            initialValue: _repeat,
            decoration: const InputDecoration(labelText: 'Tekrar'),
            items: RepeatRule.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _repeat = v);
              await _save(task);
            },
          ),
          DropdownButtonFormField<String?>(
            initialValue: _projectId,
            decoration: const InputDecoration(labelText: 'Proje'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Gelen kutusu')),
              ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
            ],
            onChanged: (v) async {
              setState(() => _projectId = v);
              await _save(task);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Not', alignLabelWithHint: true),
            onChanged: (_) => _save(task),
          ),
          const SizedBox(height: 16),
          Text('Alt görevler', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryTextFor(brightness))),
          ...task.subtasks.map(
            (s) => CheckboxListTile(
              value: s.done,
              onChanged: (_) => ref.read(tasksProvider.notifier).toggleSubtask(task.id, s.id),
              title: Text(s.title),
              controlAffinity: ListTileControlAffinity.leading,
              secondary: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref.read(tasksProvider.notifier).removeSubtask(task.id, s.id),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subtaskInput,
                  decoration: const InputDecoration(hintText: 'Alt görev ekle'),
                  onSubmitted: (v) async {
                    await ref.read(tasksProvider.notifier).addSubtask(task.id, v);
                    _subtaskInput.clear();
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  await ref.read(tasksProvider.notifier).addSubtask(task.id, _subtaskInput.text);
                  _subtaskInput.clear();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              await ref.read(tasksProvider.notifier).remove(task.id);
              widget.onClose();
            },
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Görevi sil'),
          ),
        ],
      ),
    );

    if (isSheet) return content;

    return Container(
      width: AppColors.detailPanelWidth,
      decoration: BoxDecoration(
        color: AppColors.sidebarFor(brightness),
        border: Border(left: BorderSide(color: AppColors.borderFor(brightness))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: content,
    );
  }
}
