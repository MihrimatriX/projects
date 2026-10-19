import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/od_card.dart';
import '../../../core/widgets/page_header.dart';
import '../../../data/database.dart';
import '../../../data/database_provider.dart';
import '../pause_store.dart';

enum _TimerState { idle, tracking, paused }

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  List<Project> _projects = [];
  List<TimeEntry> _entries = [];
  Project? _selected;
  TimeEntry? _active;
  _TimerState _state = _TimerState.idle;
  Timer? _tick;
  Duration _elapsed = Duration.zero;
  // Duraklatma SharedPreferences'ta açık kayıt kimliğiyle tutulur: sekme değişse
  // de uygulama kapanıp açılsa da korunur (bkz. PauseStore).
  PauseInfo _pauseInfo = const PauseInfo();
  late final PauseStore _pauseStore = PauseStore(ref.read(sharedPreferencesProvider));
  int? _selectedEntryId;
  int? _pendingDeleteId;
  bool _loading = true;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = ref.read(databaseProvider);
    final projects = await db.getAllProjects();
    final active = await db.getActiveEntry();
    final entries = await db.getTodayEntries(includeActive: true);
    if (!mounted) return;
    setState(() {
      _projects = projects;
      _active = active;
      _entries = entries;
      _loading = false;
      if (active != null) {
        _selected = projects.where((p) => p.id == active.projectId).firstOrNull;
        _pauseInfo = _pauseStore.load(active.id);
        _elapsed = _pauseInfo.trackedAt(active.startedAt, DateTime.now());
        _state = _pauseInfo.paused ? _TimerState.paused : _TimerState.tracking;
      } else {
        _selected ??= projects.isNotEmpty ? projects.first : null;
        _elapsed = Duration.zero;
        _state = _TimerState.idle;
        _pauseInfo = const PauseInfo();
      }
    });
    _startTickIfNeeded();
  }

  void _startTickIfNeeded() {
    _tick?.cancel();
    if (_state != _TimerState.tracking || _active == null) return;
    // Süre her tikte başlangıç anından yeniden hesaplanır (artırılmaz); böylece
    // Timer gecikmeleri birikmez ve ekran değişip dönülse de doğru kalır.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_active == null) return;
      setState(() {
        _elapsed = _pauseInfo.trackedAt(_active!.startedAt, DateTime.now());
      });
    });
  }

  Color _projectColor(Project p) =>
      AppColors.projectColor(p.colorArgb == 0 ? null : p.colorArgb, _projects.indexOf(p));

  Future<void> _start() async {
    if (_selected == null) {
      _snack('Önce bir proje seçin');
      return;
    }
    if (_state == _TimerState.paused && _active != null) {
      _pauseInfo = _pauseInfo.resume(DateTime.now());
      await _pauseStore.save(_active!.id, _pauseInfo);
      if (!mounted) return;
      setState(() => _state = _TimerState.tracking);
      _startTickIfNeeded();
      return;
    }
    final db = ref.read(databaseProvider);
    await db.startEntry(_selected!.id);
    _pauseInfo = const PauseInfo();
    await _pauseStore.clear();
    await _refresh();
    if (mounted) setState(() => _state = _TimerState.tracking);
  }

  Future<void> _pause() async {
    if (_state == _TimerState.tracking) {
      _tick?.cancel();
      final now = DateTime.now();
      _pauseInfo = _pauseInfo.pause(now);
      setState(() {
        _elapsed = _pauseInfo.trackedAt(_active!.startedAt, now);
        _state = _TimerState.paused;
      });
      await _pauseStore.save(_active!.id, _pauseInfo);
    } else if (_state == _TimerState.paused) {
      await _start();
    }
  }

  Future<void> _stop() async {
    if (_active == null) return;
    final db = ref.read(databaseProvider);
    // Duraklatılan süre kayda yazılmasın: bitiş anı toplam duraklatma kadar geri çekilir.
    final now = DateTime.now();
    await db.stopEntry(_active!.id, endedAt: now.subtract(_pauseInfo.totalAt(now)));
    _tick?.cancel();
    _pauseInfo = const PauseInfo();
    await _pauseStore.clear();
    if (!mounted) return;
    setState(() => _state = _TimerState.idle);
    await _refresh();
    _snack('Kayıt durduruldu');
  }

  void _toggle() {
    if (_state == _TimerState.tracking) {
      _stop();
    } else {
      _start();
    }
  }

  Future<void> _deleteEntry(int id) async {
    final db = ref.read(databaseProvider);
    if (_active?.id == id) {
      await db.stopEntry(id);
      await _pauseStore.clear();
      _tick?.cancel();
      _state = _TimerState.idle;
      _active = null;
    }
    await db.deleteEntry(id);
    if (!mounted) return;
    setState(() {
      _pendingDeleteId = null;
      if (_selectedEntryId == id) _selectedEntryId = null;
    });
    await _refresh();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Duration get _todayTotal {
    var total = Duration.zero;
    final now = DateTime.now();
    for (final e in _entries) {
      if (e.endedAt != null) {
        total += e.endedAt!.difference(e.startedAt);
      } else if (e.id == _active?.id) {
        total += _elapsed;
      } else {
        total += now.difference(e.startedAt);
      }
    }
    return total;
  }

  Map<int, Duration> get _byProject {
    final map = <int, Duration>{};
    final now = DateTime.now();
    for (final e in _entries) {
      Duration d;
      if (e.endedAt != null) {
        d = e.endedAt!.difference(e.startedAt);
      } else if (e.id == _active?.id) {
        d = _elapsed;
      } else {
        d = now.difference(e.startedAt);
      }
      map[e.projectId] = (map[e.projectId] ?? Duration.zero) + d;
    }
    return map;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final goalHours = ref.watch(settingsProvider).goalHours;
    final goal = Duration(hours: goalHours);
    final total = _todayTotal;
    final goalMet = total >= goal;
    final goalPct = goal.inSeconds == 0 ? 0.0 : (total.inSeconds / goal.inSeconds).clamp(0.0, 1.0);
    final byProject = _byProject;
    final barTotal = byProject.values.fold<Duration>(Duration.zero, (a, b) => a + b);
    final wide = MediaQuery.sizeOf(context).width >= 780;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _toggle,
        const SingleActivator(LogicalKeyboardKey.keyM): () => context.go('/pomodoro'),
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (_selectedEntryId != null) setState(() => _pendingDeleteId = _selectedEntryId);
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(
              title: 'Süre Kaydı',
              subtitle: 'Proje seç, başlat — minimum tıklama ile odak süreni takip et.',
            ),
            LayoutBuilder(
              builder: (context, c) {
                final panel = _TimerPanel(
                  state: _state,
                  elapsed: _elapsed,
                  selected: _selected,
                  projects: _projects,
                  menuOpen: _menuOpen,
                  goalHours: goalHours,
                  total: total,
                  goal: goal,
                  goalMet: goalMet,
                  goalPct: goalPct,
                  byProject: byProject,
                  barTotal: barTotal,
                  projectColor: _projectColor,
                  onSelect: (p) => setState(() {
                    _selected = p;
                    _menuOpen = false;
                  }),
                  onMenuToggle: () => setState(() => _menuOpen = !_menuOpen),
                  onStart: _start,
                  onPause: _pause,
                  onStop: _stop,
                );
                final entries = _EntriesPanel(
                  entries: _entries.reversed.toList(),
                  projects: _projects,
                  activeId: _active?.id,
                  elapsed: _elapsed,
                  total: total,
                  selectedId: _selectedEntryId,
                  pendingDeleteId: _pendingDeleteId,
                  projectColor: _projectColor,
                  onSelect: (id) => setState(() => _selectedEntryId = id),
                  onDeleteRequest: (id) => setState(() => _pendingDeleteId = id),
                  onDeleteCancel: () => setState(() => _pendingDeleteId = null),
                  onDeleteConfirm: _deleteEntry,
                );
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: panel),
                      const SizedBox(width: 24),
                      SizedBox(width: 300, child: entries),
                    ],
                  );
                }
                return Column(children: [panel, const SizedBox(height: 24), entries]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerPanel extends StatelessWidget {
  const _TimerPanel({
    required this.state,
    required this.elapsed,
    required this.selected,
    required this.projects,
    required this.menuOpen,
    required this.goalHours,
    required this.total,
    required this.goal,
    required this.goalMet,
    required this.goalPct,
    required this.byProject,
    required this.barTotal,
    required this.projectColor,
    required this.onSelect,
    required this.onMenuToggle,
    required this.onStart,
    required this.onPause,
    required this.onStop,
  });

  final _TimerState state;
  final Duration elapsed;
  final Project? selected;
  final List<Project> projects;
  final bool menuOpen;
  final int goalHours;
  final Duration total;
  final Duration goal;
  final bool goalMet;
  final double goalPct;
  final Map<int, Duration> byProject;
  final Duration barTotal;
  final Color Function(Project) projectColor;
  final void Function(Project) onSelect;
  final VoidCallback onMenuToggle;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final tracking = state == _TimerState.tracking;
    final paused = state == _TimerState.paused;
    final running = tracking || paused;
    final clock = formatClock(elapsed);

    return OdCard(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      child: Column(
        children: [
          if (running)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: tracking ? const Color(0x4014B8A6) : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: tracking ? AppColors.accent : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    paused ? 'Duraklatıldı' : 'Kayıt devam ediyor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: tracking ? AppColors.accent : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Text(
            clock,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 56,
              fontWeight: FontWeight.w600,
              color: tracking
                  ? AppColors.accent
                  : paused
                      ? AppColors.textMuted.withValues(alpha: 0.7)
                      : AppColors.textMuted,
              letterSpacing: -1,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tracking && selected != null
                ? '${selected!.name} · ${formatDurationTr(elapsed)}'
                : paused
                    ? 'Duraklatıldı — ${selected?.name ?? ''}'
                    : 'Hazır — proje seçip başlat',
            style: TextStyle(
              fontSize: 13,
              color: tracking ? AppColors.textSecondary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 28),
          if (projects.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in projects.take(3))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Chip(
                        label: p.name,
                        color: projectColor(p),
                        active: selected?.id == p.id,
                        onTap: () => onSelect(p),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _ProjectDropdown(
            projects: projects,
            selected: selected,
            open: menuOpen,
            projectColor: projectColor,
            onToggle: onMenuToggle,
            onSelect: onSelect,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!running)
                Expanded(
                  child: _OdButton(
                    label: 'Başlat',
                    icon: Icons.play_arrow,
                    color: AppColors.accent,
                    onPressed: selected == null ? null : onStart,
                  ),
                ),
              if (running) ...[
                Expanded(
                  child: _OdButton(
                    label: paused ? 'Devam' : 'Ara Ver',
                    icon: paused ? Icons.play_arrow : Icons.pause,
                    color: AppColors.accent,
                    onPressed: onPause,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OdButton(
                    label: 'Durdur',
                    icon: Icons.stop,
                    color: AppColors.danger,
                    onPressed: onStop,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'BUGÜN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: goalPct,
              minHeight: 4,
              backgroundColor: AppColors.bgElevated,
              color: goalMet ? AppColors.success : AppColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          if (barTotal.inSeconds > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final e in byProject.entries)
                      Expanded(
                        flex: (e.value.inSeconds * 1000).clamp(1, 1000000),
                        child: ColoredBox(
                          color: projectColor(projects.firstWhere((p) => p.id == e.key)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Toplam: ${formatDurationTr(total)} / ${goalHours}s hedef',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              if (goalMet)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppColors.success),
                    SizedBox(width: 4),
                    Text('Hedef tamamlandı', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Space başlat/durdur · M pomodoro · Delete seçili kaydı sil',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.active, required this.onTap});

  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.accentSoft : AppColors.bgElevated,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? Colors.transparent : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 11, color: active ? AppColors.accent : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectDropdown extends StatelessWidget {
  const _ProjectDropdown({
    required this.projects,
    required this.selected,
    required this.open,
    required this.projectColor,
    required this.onToggle,
    required this.onSelect,
  });

  final List<Project> projects;
  final Project? selected;
  final bool open;
  final Color Function(Project) projectColor;
  final VoidCallback onToggle;
  final void Function(Project) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: projects.isEmpty ? null : onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                if (selected != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: projectColor(selected!), shape: BoxShape.circle),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected?.name ?? 'Proje yok — Ayarlardan ekle',
                    style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                  ),
                ),
                const Icon(Icons.expand_more, color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        ),
        if (open && projects.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (final p in projects)
                  InkWell(
                    onTap: () => onSelect(p),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      color: selected?.id == p.id ? AppColors.accentSoft : null,
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: projectColor(p), shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          _Initial(name: p.name),
                          const SizedBox(width: 8),
                          Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(projectInitial(name), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _OdButton extends StatelessWidget {
  const _OdButton({required this.label, required this.icon, required this.color, this.onPressed});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _EntriesPanel extends StatelessWidget {
  const _EntriesPanel({
    required this.entries,
    required this.projects,
    required this.activeId,
    required this.elapsed,
    required this.total,
    required this.selectedId,
    required this.pendingDeleteId,
    required this.projectColor,
    required this.onSelect,
    required this.onDeleteRequest,
    required this.onDeleteCancel,
    required this.onDeleteConfirm,
  });

  final List<TimeEntry> entries;
  final List<Project> projects;
  final int? activeId;
  final Duration elapsed;
  final Duration total;
  final int? selectedId;
  final int? pendingDeleteId;
  final Color Function(Project) projectColor;
  final void Function(int) onSelect;
  final void Function(int) onDeleteRequest;
  final VoidCallback onDeleteCancel;
  final Future<void> Function(int) onDeleteConfirm;

  Project? _project(int id) => projects.where((p) => p.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    return OdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Bugünkü kayıtlar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ),
                Text(formatDurationTr(total), style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.accent)),
              ],
            ),
          ),
          if (pendingDeleteId != null) _ConfirmBar(
            text: _confirmText(pendingDeleteId!),
            onCancel: onDeleteCancel,
            onConfirm: () => onDeleteConfirm(pendingDeleteId!),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Henüz kayıt yok — proje seçip başlat.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            )
          else
            for (final e in entries) _EntryRow(
              entry: e,
              project: _project(e.projectId),
              running: e.id == activeId,
              duration: e.id == activeId ? elapsed : (e.endedAt != null ? e.endedAt!.difference(e.startedAt) : Duration.zero),
              selected: selectedId == e.id,
              projectColor: projectColor,
              onTap: () => onSelect(e.id),
              onDelete: () => onDeleteRequest(e.id),
            ),
        ],
      ),
    );
  }

  String _confirmText(int id) {
    final e = entries.firstWhere((x) => x.id == id);
    final p = _project(e.projectId);
    final d = e.id == activeId ? elapsed : (e.endedAt != null ? e.endedAt!.difference(e.startedAt) : Duration.zero);
    return '${p?.name ?? 'Kayıt'} — ${formatDurationTr(d)} silinsin mi?';
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.text, required this.onCancel, required this.onConfirm});

  final String text;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14EF4444),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x40EF4444)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          TextButton(onPressed: onCancel, child: const Text('İptal')),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 32)),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.project,
    required this.running,
    required this.duration,
    required this.selected,
    required this.projectColor,
    required this.onTap,
    required this.onDelete,
  });

  final TimeEntry entry;
  final Project? project;
  final bool running;
  final Duration duration;
  final bool selected;
  final Color Function(Project) projectColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = project;
    return Material(
      color: selected ? AppColors.bgHover : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: const BorderSide(color: AppColors.border),
              left: running
                  ? const BorderSide(color: AppColors.accent, width: 3)
                  : selected
                      ? const BorderSide(color: AppColors.accent, width: 2)
                      : BorderSide.none,
            ),
          ),
          child: Row(
            children: [
              if (p != null) Container(width: 8, height: 8, decoration: BoxDecoration(color: projectColor(p), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              if (p != null) _Initial(name: p.name),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p?.name ?? 'Proje #${entry.projectId}', style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    Text(
                      '${formatTimeOfDay(entry.startedAt)} — ${running ? 'devam' : formatTimeOfDay(entry.endedAt!)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Text(formatDurationTr(duration), style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.accent)),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
