import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/task_filters.dart';
import '../../../core/theme/app_colors.dart';
import '../../notes/presentation/notes_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tasks/models/task_item.dart';
import '../../tasks/presentation/tasks_main_view.dart';
import '../../tasks/providers/task_view_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../../tasks/widgets/project_sidebar.dart';
import '../../tasks/widgets/task_detail_sheet.dart';

enum ShellSection { tasks, notes, settings }

enum MobileTab { today, inbox, upcoming, notes, settings }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  ShellSection _section = ShellSection.tasks;
  MobileTab _tab = MobileTab.today;
  String? _selectedTaskId;
  final _quickAddFocus = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _quickAddFocus.dispose();
    super.dispose();
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= AppLayout.breakpointWide;

  @override
  Widget build(BuildContext context) {
    if (_isWide) return _buildWide();
    return _buildMobile();
  }

  Widget _buildWide() {
    final brightness = Theme.of(context).brightness;
    final selectedTask = _findTask(_selectedTaskId);

    return Scaffold(
      body: Row(
        children: [
          ProjectSidebar(
            showSettings: true,
            onTasksNav: () => setState(() => _section = ShellSection.tasks),
            onNotesTap: () => setState(() {
              _section = ShellSection.notes;
              _selectedTaskId = null;
            }),
            onSettingsTap: () => setState(() {
              _section = ShellSection.settings;
              _selectedTaskId = null;
            }),
          ),
          VerticalDivider(width: 1, color: AppColors.borderFor(brightness)),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _mainContent(useInlineDetail: true)),
                if (_section == ShellSection.tasks && selectedTask != null)
                  TaskDetailPanel(
                    key: ValueKey(selectedTask.id),
                    initial: selectedTask,
                    onClose: () => setState(() => _selectedTaskId = null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    final onTasks = _tab == MobileTab.today || _tab == MobileTab.inbox || _tab == MobileTab.upcoming;

    return Scaffold(
      key: _scaffoldKey,
      drawer: onTasks
          ? Drawer(
              child: ProjectSidebar(
                compact: true,
                onNotesTap: () {
                  Navigator.pop(context);
                  setState(() => _tab = MobileTab.notes);
                },
                onSettingsTap: () {
                  Navigator.pop(context);
                  setState(() => _tab = MobileTab.settings);
                },
                onNavigated: () => Navigator.pop(context),
              ),
            )
          : null,
      appBar: onTasks
          ? AppBar(
              title: const Text('Akıllı Liste'),
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            )
          : AppBar(title: Text(_mobileTitle)),
      body: _mainContent(useInlineDetail: false),
      floatingActionButton: onTasks
          ? FloatingActionButton(
              onPressed: () => _quickAddFocus.requestFocus(),
              tooltip: 'Görev ekle',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) {
          setState(() {
            _tab = MobileTab.values[i];
            _section = _tab == MobileTab.notes
                ? ShellSection.notes
                : _tab == MobileTab.settings
                    ? ShellSection.settings
                    : ShellSection.tasks;
          });
          _syncTaskView(_tab);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Bugün'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox), label: 'Gelen'),
          NavigationDestination(icon: Icon(Icons.upcoming_outlined), selectedIcon: Icon(Icons.upcoming), label: 'Yaklaşan'),
          NavigationDestination(icon: Icon(Icons.note_outlined), selectedIcon: Icon(Icons.note), label: 'Notlar'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ayarlar'),
        ],
      ),
    );
  }

  Widget _mainContent({required bool useInlineDetail}) {
    if (!_isWide) {
      return switch (_tab) {
        MobileTab.notes => const NotesScreen(),
        MobileTab.settings => const SettingsScreen(),
        _ => _TasksPane(
            quickAddFocus: _quickAddFocus,
            selectedTaskId: _selectedTaskId,
            useInlineDetail: useInlineDetail,
            onSelectTask: (t) => setState(() => _selectedTaskId = t.id),
            onClearSelection: () => setState(() => _selectedTaskId = null),
          ),
      };
    }

    return switch (_section) {
      ShellSection.notes => const NotesScreen(),
      ShellSection.settings => const SettingsScreen(),
      ShellSection.tasks => _TasksPane(
          quickAddFocus: _quickAddFocus,
          selectedTaskId: _selectedTaskId,
          useInlineDetail: useInlineDetail,
          onSelectTask: (t) => setState(() => _selectedTaskId = t.id),
          onClearSelection: () => setState(() => _selectedTaskId = null),
        ),
    };
  }

  String get _mobileTitle => switch (_tab) {
        MobileTab.today => 'Bugün',
        MobileTab.inbox => 'Gelen Kutusu',
        MobileTab.upcoming => 'Yaklaşan',
        MobileTab.notes => 'Notlar',
        MobileTab.settings => 'Ayarlar',
      };

  void _syncTaskView(MobileTab tab) {
    switch (tab) {
      case MobileTab.today:
        selectNavView(ref, TaskViewKind.today);
      case MobileTab.inbox:
        selectNavView(ref, TaskViewKind.inbox);
      case MobileTab.upcoming:
        selectNavView(ref, TaskViewKind.upcoming);
      default:
        break;
    }
  }

  TaskItem? _findTask(String? id) {
    if (id == null) return null;
    final tasks = ref.read(tasksProvider).value ?? [];
    for (final t in tasks) {
      if (t.id == id) return t;
    }
    return null;
  }
}

class _TasksPane extends ConsumerWidget {
  const _TasksPane({
    required this.quickAddFocus,
    required this.useInlineDetail,
    required this.onSelectTask,
    required this.onClearSelection,
    this.selectedTaskId,
  });

  final FocusNode quickAddFocus;
  final bool useInlineDetail;
  final String? selectedTaskId;
  final ValueChanged<TaskItem> onSelectTask;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final animDuration = reduce ? Duration.zero : const Duration(milliseconds: 150);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN): () => quickAddFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.escape): onClearSelection,
      },
      child: Focus(
        autofocus: true,
        child: TasksMainView(
          quickAddFocus: quickAddFocus,
          selectedTaskId: selectedTaskId,
          useInlineDetail: useInlineDetail,
          animDuration: animDuration,
          onSelectTask: onSelectTask,
        ),
      ),
    );
  }
}
