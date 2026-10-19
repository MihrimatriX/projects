import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/date_utils.dart';
import '../../../core/notification_service.dart';
import '../../../core/recurrence.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/models/calendar_event.dart';
import '../../events/presentation/event_form_dialog.dart';
import '../../events/providers/events_provider.dart';
import '../../timer/providers/pomodoro_provider.dart';
import '../../timer/widgets/pomodoro_panel.dart';
import '../models/calendar_view_mode.dart';
import '../widgets/calendar_views.dart';
import '../widgets/mini_month_calendar.dart';
import '../widgets/view_switcher.dart';

class _NewEventIntent extends Intent {
  const _NewEventIntent();
}

class _TodayIntent extends Intent {
  const _TodayIntent();
}

class _SearchIntent extends Intent {
  const _SearchIntent();
}

class _TogglePomoIntent extends Intent {
  const _TogglePomoIntent();
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarViewMode _viewMode = CalendarViewMode.week;
  late DateTime _focusedDay;
  late DateTime _focusedMonth;
  Timer? _reminderTimer;
  DateTime _lastReminderCheck = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = dateOnly(now);
    _focusedMonth = startOfMonth(now);
    // Sistem bildirimi olmayan platformlarda (Windows, web) uygulama içi hatırlatıcı.
    // Duvar saatine göre aralık sorgulanır; zamanlayıcının gecikmesi/uyku bir şey kaçırmaz.
    if (!NotificationService.supported) {
      _reminderTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkReminders());
    }
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkReminders() async {
    final from = _lastReminderCheck;
    final now = DateTime.now();
    _lastReminderCheck = now;
    final events = ref.read(eventsProvider).value;
    if (events == null || !await NotificationService.isEnabled() || !mounted) return;
    final due = NotificationService.dueReminders(events, from, now);
    if (due.isEmpty) return;
    SystemSound.play(SystemSoundType.alert);
    for (final o in due) {
      final when = o.event.isAllDay ? 'bugün' : 'saat ${formatTime(o.start)}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 20),
          showCloseIcon: true,
          content: Text('Hatırlatıcı: ${o.event.title} — $when'),
        ),
      );
    }
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _focusedDay = dateOnly(now);
      _focusedMonth = startOfMonth(now);
    });
  }

  void _shift(int direction) {
    setState(() {
      switch (_viewMode) {
        case CalendarViewMode.week:
          _focusedDay =
              DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day + 7 * direction);
          _focusedMonth = startOfMonth(_focusedDay);
        case CalendarViewMode.month:
          _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + direction);
          _focusedDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
        case CalendarViewMode.day:
          _focusedDay = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day + direction);
          _focusedMonth = startOfMonth(_focusedDay);
      }
    });
  }

  ({DateTime start, DateTime end}) _visibleRange() {
    switch (_viewMode) {
      case CalendarViewMode.week:
        final start = startOfWeek(_focusedDay);
        return (start: start, end: addDays(endOfWeek(_focusedDay), 1));
      case CalendarViewMode.month:
        final days = daysInMonthGrid(_focusedMonth);
        return (start: days.first, end: addDays(days.last, 1));
      case CalendarViewMode.day:
        return (start: _focusedDay, end: addDays(_focusedDay, 1));
    }
  }

  String _headerLabel() {
    switch (_viewMode) {
      case CalendarViewMode.week:
        return formatWeekRange(_focusedDay);
      case CalendarViewMode.month:
        return DateFormat('MMMM y', 'tr_TR').format(_focusedMonth);
      case CalendarViewMode.day:
        return DateFormat('d MMMM y, EEEE', 'tr_TR').format(_focusedDay);
    }
  }

  Future<void> _openEventForm({CalendarEvent? existing, DateTime? initialStart}) async {
    final result = await showEventFormDialog(
      context,
      existing: existing,
      initialStart: initialStart ?? _focusedDay.add(const Duration(hours: 9)),
    );
    if (result == null) return;
    final notifier = ref.read(eventsProvider.notifier);
    if (existing != null) {
      await notifier.updateEvent(result);
    } else {
      await notifier.add(result);
    }
  }

  Future<void> _onEventTap(EventOccurrence occurrence) async {
    await _openEventForm(existing: occurrence.event);
  }

  void _showMiniCalendarSheet(BuildContext context, List<CalendarEvent> events) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: MiniMonthCalendar(
          focusedMonth: _focusedMonth,
          selectedDay: _focusedDay,
          events: events,
          onDaySelected: (d) {
            setState(() {
              _focusedDay = d;
              _focusedMonth = startOfMonth(d);
            });
            Navigator.pop(ctx);
          },
          onMonthChanged: (m) => setState(() => _focusedMonth = m),
        ),
      ),
    );
  }

  void _showPomodoroSheet(BuildContext context, String? linked) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: PomodoroPanel(linkedEventTitle: linked),
      ),
    );
  }

  Future<void> _showSearch(List<CalendarEvent> events) async {
    final queryCtrl = TextEditingController(text: ref.read(eventSearchQueryProvider));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          var query = queryCtrl.text;
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final filtered = filterEventsByQuery(events, query);
              final range = _visibleRange();
              final occurrences = expandEvents(filtered, range.start, range.end);

              return Dialog(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.search,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: queryCtrl,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Etkinlik ara…',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onChanged: (v) => setLocal(() => query = v),
                                onSubmitted: (v) {
                                  ref.read(eventSearchQueryProvider.notifier).state = v;
                                  Navigator.pop(ctx);
                                },
                              ),
                            ),
                            Text('Esc',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: isDark
                                        ? AppColors.textMutedDark
                                        : AppColors.textMutedLight)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: filtered.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Eşleşen etkinlik yok',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: isDark
                                            ? AppColors.textMutedDark
                                            : AppColors.textMutedLight),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: filtered.length,
                                  itemBuilder: (_, i) {
                                    final e = filtered[i];
                                    final occ = occurrences.firstWhere(
                                      (o) => o.event.id == e.id,
                                      orElse: () =>
                                          EventOccurrence(event: e, start: e.start, end: e.end),
                                    );
                                    return ListTile(
                                      title: Text(e.title),
                                      subtitle: Text(
                                        '${DateFormat('d MMM', 'tr_TR').format(occ.start)} · ${formatTime(occ.start)}–${formatTime(occ.end)}',
                                        style:
                                            const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                      ),
                                      onTap: () {
                                        ref.read(eventSearchQueryProvider.notifier).state = e.title;
                                        Navigator.pop(ctx);
                                        _openEventForm(existing: e);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      queryCtrl.dispose();
    }
  }

  String? _linkedEventTitle(List<CalendarEvent> events) {
    final today = dateOnly(DateTime.now());
    final range = (start: today, end: addDays(today, 1));
    final todayEvents = expandEvents(events, range.start, range.end)
        .where((o) => !o.event.isAllDay)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (todayEvents.isEmpty) return null;
    final now = DateTime.now();
    final upcoming = todayEvents.where((o) => o.end.isAfter(now)).toList();
    return (upcoming.isNotEmpty ? upcoming.first : todayEvents.last).event.title;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final searchQuery = ref.watch(eventSearchQueryProvider);
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.wideBreakpoint;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final gridBg = isDark ? AppColors.bgGridDark : AppColors.bgGridLight;

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyN): const _NewEventIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyT): const _TodayIntent(),
        LogicalKeySet(LogicalKeyboardKey.slash): const _SearchIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): const _TogglePomoIntent(),
      },
      child: Actions(
        actions: {
          _NewEventIntent: CallbackAction<_NewEventIntent>(
            onInvoke: (_) {
              _openEventForm();
              return null;
            },
          ),
          _TodayIntent: CallbackAction<_TodayIntent>(
            onInvoke: (_) {
              _goToday();
              return null;
            },
          ),
          _SearchIntent: CallbackAction<_SearchIntent>(
            onInvoke: (_) {
              final events = ref.read(eventsProvider).value ?? [];
              _showSearch(events);
              return null;
            },
          ),
          _TogglePomoIntent: CallbackAction<_TogglePomoIntent>(
            onInvoke: (_) {
              final pomo = ref.read(pomodoroProvider);
              final notifier = ref.read(pomodoroProvider.notifier);
              if (pomo.running) {
                notifier.pause();
              } else {
                notifier.start();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
              data: (events) {
                final filtered = filterEventsByQuery(events, searchQuery);
                final range = _visibleRange();
                final occurrences = expandEvents(filtered, range.start, range.end);
                final linked = _linkedEventTitle(filtered);

                final main = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CalendarToolbar(
                      title: _headerLabel(),
                      viewMode: _viewMode,
                      onPrev: () => _shift(-1),
                      onNext: () => _shift(1),
                      onToday: _goToday,
                      onViewChanged: (m) => setState(() => _viewMode = m),
                      onNewEvent: () => _openEventForm(),
                      onSearch: () => _showSearch(filtered),
                      showMobileActions: !wide,
                      onMiniCal: () => _showMiniCalendarSheet(context, filtered),
                      onPomodoro: () => _showPomodoroSheet(context, linked),
                    ),
                    if (searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: InputChip(
                            label: Text('Arama: $searchQuery'),
                            onDeleted: () => ref.read(eventSearchQueryProvider.notifier).state = '',
                          ),
                        ),
                      ),
                    Expanded(
                      child: ColoredBox(
                        color: gridBg,
                        child: switch (_viewMode) {
                          CalendarViewMode.week => WeekView(
                              anchor: _focusedDay,
                              occurrences: occurrences,
                              onEventTap: _onEventTap,
                              onSlotTap: (day, hour) => _openEventForm(
                                initialStart: DateTime(day.year, day.month, day.day, hour),
                              ),
                            ),
                          CalendarViewMode.month => MonthView(
                              month: _focusedMonth,
                              occurrences: occurrences,
                              onDayTap: (d) => setState(() {
                                _focusedDay = d;
                                _viewMode = CalendarViewMode.day;
                              }),
                              onEventTap: _onEventTap,
                            ),
                          CalendarViewMode.day => DayView(
                              day: _focusedDay,
                              occurrences: occurrences,
                              onEventTap: _onEventTap,
                            ),
                        },
                      ),
                    ),
                  ],
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: AppLayout.sidebarWidth,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.bgSidebarDark : AppColors.bgSidebarLight,
                          border: Border(right: BorderSide(color: border)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                          child: MiniMonthCalendar(
                            focusedMonth: _focusedMonth,
                            selectedDay: _focusedDay,
                            events: filtered,
                            showSidebarActions: true,
                            onDaySelected: (d) => setState(() {
                              _focusedDay = d;
                              _focusedMonth = startOfMonth(d);
                            }),
                            onMonthChanged: (m) => setState(() => _focusedMonth = m),
                          ),
                        ),
                      ),
                      Expanded(child: main),
                      Container(
                        width: AppLayout.pomodoroWidth,
                        decoration: BoxDecoration(
                          color: gridBg,
                          border: Border(left: BorderSide(color: border)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: PomodoroPanel(linkedEventTitle: linked),
                        ),
                      ),
                    ],
                  );
                }

                return main;
              },
            ),
            floatingActionButton: wide
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _openEventForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Etkinlik'),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.title,
    required this.viewMode,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
    required this.onViewChanged,
    required this.onNewEvent,
    required this.onSearch,
    required this.showMobileActions,
    required this.onMiniCal,
    required this.onPomodoro,
  });

  final String title;
  final CalendarViewMode viewMode;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<CalendarViewMode> onViewChanged;
  final VoidCallback onNewEvent;
  final VoidCallback onSearch;
  final bool showMobileActions;
  final VoidCallback onMiniCal;
  final VoidCallback onPomodoro;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridBg = isDark ? AppColors.bgGridDark : AppColors.bgGridLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: gridBg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarIconButton(icon: Icons.chevron_left, onPressed: onPrev, tooltip: 'Önceki'),
              TextButton(onPressed: onToday, child: const Text('Bugün')),
              _ToolbarIconButton(icon: Icons.chevron_right, onPressed: onNext, tooltip: 'Sonraki'),
            ],
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width < 768 ? 16 : 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.02,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          if (showMobileActions) ...[
            _ToolbarIconButton(
                icon: Icons.calendar_month_outlined, onPressed: onMiniCal, tooltip: 'Mini takvim'),
            _ToolbarIconButton(
                icon: Icons.timer_outlined, onPressed: onPomodoro, tooltip: 'Pomodoro'),
          ],
          const Spacer(),
          ViewSwitcher(mode: viewMode, onChanged: onViewChanged),
          const SizedBox(width: 8),
          _ToolbarIconButton(icon: Icons.search, onPressed: onSearch, tooltip: 'Ara (/)'),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: onNewEvent,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Etkinlik'),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
    );
  }
}
