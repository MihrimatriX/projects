import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs_provider.dart';
import '../../../core/task_filters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../projects/models/project_item.dart';
import '../../projects/providers/projects_provider.dart';
import '../../tags/providers/tags_provider.dart';
import '../providers/task_view_provider.dart';
import '../providers/tasks_provider.dart';

class ProjectSidebar extends ConsumerWidget {
  const ProjectSidebar({
    super.key,
    this.compact = false,
    this.showSettings = false,
    this.onNotesTap,
    this.onSettingsTap,
    this.onTasksNav,
    this.onNavigated,
  });

  final bool compact;
  final bool showSettings;
  final VoidCallback? onNotesTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onTasksNav;
  final VoidCallback? onNavigated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(taskViewProvider);
    final tasks = ref.watch(tasksProvider).value ?? [];
    final projects = ref.watch(projectsProvider).value ?? [];
    final tags = ref.watch(tagsProvider).value ?? [];
    final brightness = Theme.of(context).brightness;
    final themeMode = ref.watch(themeModeProvider);
    final search = ref.watch(searchQueryProvider);

    void nav(VoidCallback action, {bool isTaskNav = false}) {
      if (isTaskNav) onTasksNav?.call();
      action();
      onNavigated?.call();
    }

    return Container(
      width: compact ? null : AppLayout.sidebarWidth,
      color: AppColors.sidebarFor(brightness),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        children: [
          _BrandRow(brightness: brightness),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Ara',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                filled: true,
                fillColor: AppColors.cardFor(brightness),
              ),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          if (search.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: InputChip(
                label: Text('Aranıyor: $search', style: const TextStyle(fontSize: 11)),
                onDeleted: () => ref.read(searchQueryProvider.notifier).state = '',
              ),
            ),
          const SizedBox(height: 14),
          _NavTile(
            icon: Icons.today_outlined,
            selectedIcon: Icons.today,
            label: 'Bugün',
            count: countForView(tasks, const TaskView(TaskViewKind.today)),
            selected: view.kind == TaskViewKind.today,
            onTap: () => nav(() => selectNavView(ref, TaskViewKind.today), isTaskNav: true),
          ),
          _NavTile(
            icon: Icons.inbox_outlined,
            selectedIcon: Icons.inbox,
            label: 'Gelen Kutusu',
            count: countForView(tasks, const TaskView(TaskViewKind.inbox)),
            selected: view.kind == TaskViewKind.inbox,
            onTap: () => nav(() => selectNavView(ref, TaskViewKind.inbox), isTaskNav: true),
          ),
          _NavTile(
            icon: Icons.upcoming_outlined,
            label: 'Yaklaşan',
            count: countForView(tasks, const TaskView(TaskViewKind.upcoming)),
            selected: view.kind == TaskViewKind.upcoming,
            onTap: () => nav(() => selectNavView(ref, TaskViewKind.upcoming), isTaskNav: true),
          ),
          _NavTile(
            icon: Icons.list_alt_outlined,
            label: 'Tümü',
            count: countForView(tasks, const TaskView(TaskViewKind.all)),
            selected: view.kind == TaskViewKind.all,
            onTap: () => nav(() => selectNavView(ref, TaskViewKind.all), isTaskNav: true),
          ),
          _NavTile(
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
            label: 'Takvim',
            count: countForView(tasks, const TaskView(TaskViewKind.calendar)),
            selected: view.kind == TaskViewKind.calendar,
            onTap: () => nav(() => selectNavView(ref, TaskViewKind.calendar), isTaskNav: true),
          ),
          _NavTile(
            icon: Icons.note_outlined,
            selectedIcon: Icons.note,
            label: 'Hızlı Notlar',
            count: null,
            selected: false,
            onTap: () => nav(() => onNotesTap?.call()),
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _SectionLabel('Etiketler'),
            ...tags.map(
              (tag) => _SidebarTile(
                leading: Icon(Icons.sell_outlined, size: 16, color: AppColors.projectColor(tag.colorIndex)),
                label: tag.display,
                count: countForView(tasks, TaskView(TaskViewKind.tag, tagId: tag.id)),
                selected: view.kind == TaskViewKind.tag && view.tagId == tag.id,
                onTap: () => nav(() => selectTagView(ref, tag), isTaskNav: true),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _SectionLabel('Projeler'),
          ...projects.map(
            (p) => _SidebarTile(
              leading: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.projectColor(p.colorIndex),
                  shape: BoxShape.circle,
                ),
              ),
              label: p.name,
              count: countForView(tasks, TaskView(TaskViewKind.project, projectId: p.id)),
              selected: view.kind == TaskViewKind.project && view.projectId == p.id,
              onTap: () => nav(() => selectProjectView(ref, p), isTaskNav: true),
              onLongPress: () => _editProject(context, ref, p),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Icon(Icons.add, size: 20, color: AppColors.secondaryTextFor(brightness)),
              title: Text('Proje ekle', style: TextStyle(fontSize: 14, color: AppColors.secondaryTextFor(brightness))),
              onTap: () => _addProject(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          if (showSettings)
            _NavTile(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Ayarlar',
              count: null,
              selected: false,
              onTap: () => nav(() => onSettingsTap?.call()),
            ),
          _ThemeToggle(
            isDark: themeMode == ThemeMode.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).set(v ? ThemeMode.dark : ThemeMode.light),
          ),
        ],
      ),
    );
  }

  Future<void> _addProject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni proje'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Proje adı'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Oluştur')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      final p = await ref.read(projectsProvider.notifier).add(name);
      if (p != null) selectProjectView(ref, p);
    }
  }

  Future<void> _editProject(BuildContext context, WidgetRef ref, ProjectItem project) async {
    final controller = TextEditingController(text: project.name);
    var colorIndex = project.colorIndex;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Projeyi düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Ad')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: List.generate(AppColors.projectColors.length, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => colorIndex = i),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.projectColor(i),
                        shape: BoxShape.circle,
                        border: colorIndex == i ? Border.all(color: AppColors.accent, width: 2) : null,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(projectsProvider.notifier).remove(project.id);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Sil', style: TextStyle(color: AppColors.danger)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    final newName = controller.text.trim();
    controller.dispose();
    if (saved == true && newName.isNotEmpty) {
      await ref.read(projectsProvider.notifier).updateProject(
            project.copyWith(name: newName, colorIndex: colorIndex),
          );
    }
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primaryTextFor(brightness),
              borderRadius: BorderRadius.circular(7),
            ),
            alignment: Alignment.center,
            child: Text(
              'A',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.sidebarFor(brightness),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Akıllı Liste',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTextFor(brightness),
                ),
              ),
              Text(
                'Yerel ve hızlı',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryTextFor(brightness)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 5),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.08 * 11,
          color: AppColors.secondaryTextFor(Theme.of(context).brightness),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, required this.onChanged});

  final bool isDark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppLayout.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLayout.radius),
        onTap: () => onChanged(!isDark),
        hoverColor: AppColors.hoverFor(brightness),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.dark_mode_outlined, size: 20, color: AppColors.secondaryTextFor(brightness)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Koyu tema',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.secondaryTextFor(brightness)),
                ),
              ),
              Switch(value: isDark, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.selectedIcon,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SidebarTile(
      leading: Icon(
        selected && selectedIcon != null ? selectedIcon! : icon,
        size: 20,
        color: selected ? AppColors.primaryTextFor(Theme.of(context).brightness) : AppColors.secondaryTextFor(Theme.of(context).brightness),
      ),
      label: label,
      count: count,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.leading,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final Widget leading;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: selected ? AppColors.selectedFor(brightness) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppLayout.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppLayout.radius),
        onTap: onTap,
        onLongPress: onLongPress,
        hoverColor: AppColors.hoverFor(brightness),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 24, child: Center(child: leading)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: selected ? AppColors.primaryTextFor(brightness) : AppColors.secondaryTextFor(brightness),
                  ),
                ),
              ),
              if (count != null && count! > 0)
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColors.secondaryTextFor(brightness),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
