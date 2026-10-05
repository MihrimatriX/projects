import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/date_utils.dart';
import '../../../core/natural_language_parser.dart';
import '../../../core/theme/app_theme.dart';
import '../../events/models/calendar_event.dart';
import '../../events/providers/events_provider.dart';

Future<CalendarEvent?> showEventFormDialog(
  BuildContext context, {
  CalendarEvent? existing,
  DateTime? initialStart,
}) {
  return showDialog<CalendarEvent>(
    context: context,
    builder: (ctx) => _EventFormDialog(
      existing: existing,
      initialStart: initialStart,
    ),
  );
}

class _EventFormDialog extends ConsumerStatefulWidget {
  const _EventFormDialog({this.existing, this.initialStart});

  final CalendarEvent? existing;
  final DateTime? initialStart;

  @override
  ConsumerState<_EventFormDialog> createState() => _EventFormDialogState();
}

class _EventFormDialogState extends ConsumerState<_EventFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _nlCtrl;
  late DateTime _start;
  late DateTime _end;
  late int _colorIndex;
  late RecurrenceType _recurrence;
  late int _reminderMinutes;
  late bool _isAllDay;
  DateTime? _until;

  static const _reminderOptions = [0, 5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?.title ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
    _nlCtrl = TextEditingController();
    final base =
        existing?.start ?? widget.initialStart ?? DateTime.now().add(const Duration(hours: 1));
    _start = DateTime(base.year, base.month, base.day, base.hour, 0);
    _end = existing?.end ?? _start.add(const Duration(hours: 1));
    _colorIndex = existing?.colorIndex ?? 0;
    _recurrence = existing?.recurrence ?? RecurrenceType.none;
    _reminderMinutes = existing?.reminderMinutes ?? 15;
    _isAllDay = existing?.isAllDay ?? false;
    _until = existing?.recurrenceUntil;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _nlCtrl.dispose();
    super.dispose();
  }

  void _applyNaturalLanguage() {
    final parsed = parseNaturalLanguageEvent(_nlCtrl.text);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anlaşılamadı. Örnek: Yarın 15:00 toplantı')),
      );
      return;
    }
    setState(() {
      _titleCtrl.text = parsed.title;
      _start = parsed.start;
      _end = parsed.end;
      _isAllDay = false;
    });
  }

  // Sabit 2020-2035 aralığı, dışındaki bir etkinlik açıldığında tarih seçiciyi
  // assert ile çökertiyordu.
  static DateTime _minDate(DateTime d) => DateTime(d.year - 10);
  static DateTime _maxDate(DateTime d) => DateTime(d.year + 10, 12, 31);

  Future<void> _pickUntil() async {
    final first = dateOnly(_start);
    final initial = _until ?? addDays(first, 30);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: _maxDate(initial),
      helpText: 'Tekrarın son günü',
    );
    if (date != null && mounted) setState(() => _until = date);
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: _minDate(_start),
      lastDate: _maxDate(_start),
    );
    if (date == null || !mounted) return;
    if (_isAllDay) {
      setState(() {
        _start = DateTime(date.year, date.month, date.day);
        _end = addDays(_start, 1);
      });
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null || !mounted) return;
    setState(() {
      _start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (!_end.isAfter(_start)) {
        _end = _start.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _isAllDay ? addDays(_end, -1) : _end,
      firstDate: dateOnly(_start),
      lastDate: _maxDate(_end),
    );
    if (date == null || !mounted) return;
    if (_isAllDay) {
      setState(() => _end = addDays(DateTime(date.year, date.month, date.day), 1));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
    );
    if (time == null || !mounted) return;
    setState(() {
      _end = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    if (!_isAllDay && !_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitiş, başlangıçtan sonra olmalı')),
      );
      return;
    }
    if (_recurrence != RecurrenceType.none &&
        _until != null &&
        _until!.isBefore(dateOnly(_start))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tekrar bitişi, başlangıçtan önce olamaz')),
      );
      return;
    }
    final event = CalendarEvent(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      start: _start,
      // Çok günlük tüm gün etkinliğinde seçilen bitiş korunur.
      end: _isAllDay ? (_end.isAfter(_start) ? _end : addDays(_start, 1)) : _end,
      colorIndex: _colorIndex,
      recurrence: _recurrence,
      recurrenceUntil: _recurrence == RecurrenceType.none ? null : _until,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      reminderMinutes: _reminderMinutes,
      isAllDay: _isAllDay,
      isFocusBlock: widget.existing?.isFocusBlock ?? false,
    );
    Navigator.pop(context, event);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = _isAllDay ? DateFormat('d MMM y', 'tr_TR') : DateFormat('d MMM y, HH:mm', 'tr_TR');

    return AlertDialog(
      title: Text(widget.existing == null ? 'Yeni etkinlik' : 'Etkinliği düzenle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.existing == null) ...[
              TextField(
                controller: _nlCtrl,
                decoration: InputDecoration(
                  labelText: 'Doğal dil',
                  hintText: 'Yarın 15:00 toplantı',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.auto_fix_high),
                    onPressed: _applyNaturalLanguage,
                  ),
                ),
                onSubmitted: (_) => _applyNaturalLanguage(),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Açıklama (isteğe bağlı)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tüm gün'),
              value: _isAllDay,
              onChanged: (v) => setState(() {
                _isAllDay = v;
                if (v) {
                  _start = DateTime(_start.year, _start.month, _start.day);
                  _end = addDays(_start, 1);
                }
              }),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Başlangıç'),
              subtitle: Text(fmt.format(_start)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickStart,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bitiş'),
              subtitle: Text(fmt.format(_isAllDay ? addDays(_end, -1) : _end)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickEnd,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Renk', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(AppColors.eventPalette.length, (i) {
                final color = AppColors.eventPalette[i];
                final selected = _colorIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(
                              color: Theme.of(context).colorScheme.onSurface,
                              width: 2,
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceType>(
              initialValue: _recurrence,
              decoration: const InputDecoration(
                labelText: 'Tekrar',
                border: OutlineInputBorder(),
              ),
              items: RecurrenceType.values
                  .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _recurrence = v);
              },
            ),
            if (_recurrence != RecurrenceType.none)
              ListTile(
                key: const Key('recurrence-until'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Tekrar bitişi'),
                subtitle: Text(
                  _until == null ? 'Süresiz' : DateFormat('d MMM y', 'tr_TR').format(_until!),
                ),
                onTap: _pickUntil,
                trailing: _until == null
                    ? const Icon(Icons.event_busy)
                    : IconButton(
                        tooltip: 'Süresiz yap',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _until = null),
                      ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _reminderMinutes,
              decoration: const InputDecoration(
                labelText: 'Hatırlatıcı',
                border: OutlineInputBorder(),
              ),
              items: ({..._reminderOptions, _reminderMinutes}.toList()..sort())
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m == 0 ? 'Yok' : '$m dk önce'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _reminderMinutes = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              await ref.read(eventsProvider.notifier).remove(widget.existing!.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }
}
