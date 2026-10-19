import '../../../core/date_utils.dart';

enum RecurrenceType { none, daily, weekly, monthly }

extension RecurrenceTypeLabel on RecurrenceType {
  String get label => switch (this) {
        RecurrenceType.none => 'Tek seferlik',
        RecurrenceType.daily => 'Günlük',
        RecurrenceType.weekly => 'Haftalık',
        RecurrenceType.monthly => 'Aylık',
      };
}

RecurrenceType? recurrenceFromRrule(String? rrule) {
  if (rrule == null) return null;
  final upper = rrule.toUpperCase();
  if (upper.contains('FREQ=DAILY')) return RecurrenceType.daily;
  if (upper.contains('FREQ=WEEKLY')) return RecurrenceType.weekly;
  if (upper.contains('FREQ=MONTHLY')) return RecurrenceType.monthly;
  return null;
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.colorIndex = 0,
    this.recurrence = RecurrenceType.none,
    this.description,
    this.reminderMinutes = 0,
    this.isAllDay = false,
    this.isFocusBlock = false,
    this.recurrenceUntil,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final int colorIndex;
  final RecurrenceType recurrence;
  final String? description;
  final int reminderMinutes;
  final bool isAllDay;
  final bool isFocusBlock;

  /// Tekrarın son günü (dahil, yalnızca tarih). null: süresiz tekrar.
  final DateTime? recurrenceUntil;

  DateTime get date => start;

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    int? colorIndex,
    RecurrenceType? recurrence,
    String? description,
    int? reminderMinutes,
    bool? isAllDay,
    bool? isFocusBlock,
    DateTime? recurrenceUntil,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      colorIndex: colorIndex ?? this.colorIndex,
      recurrence: recurrence ?? this.recurrence,
      description: description ?? this.description,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isAllDay: isAllDay ?? this.isAllDay,
      isFocusBlock: isFocusBlock ?? this.isFocusBlock,
      recurrenceUntil: recurrenceUntil ?? this.recurrenceUntil,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'colorIndex': colorIndex,
        'recurrence': recurrence.name,
        if (description != null && description!.isNotEmpty) 'description': description,
        if (reminderMinutes > 0) 'reminderMinutes': reminderMinutes,
        if (isAllDay) 'isAllDay': isAllDay,
        if (isFocusBlock) 'isFocusBlock': isFocusBlock,
        if (recurrenceUntil != null)
          'recurrenceUntil': dateOnly(recurrenceUntil!).toIso8601String().substring(0, 10),
      };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final startRaw = json['start'] as String? ?? json['date'] as String;
    final start = DateTime.parse(startRaw);
    final endRaw = json['end'] as String?;
    final isAllDay = json['isAllDay'] as bool? ?? false;
    final end = endRaw != null
        ? DateTime.parse(endRaw)
        : isAllDay
            ? addDays(start, 1)
            : start.add(const Duration(hours: 1));
    final recurrenceRaw = json['recurrence'] as String?;
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      start: start,
      end: end,
      colorIndex: json['colorIndex'] as int? ?? 0,
      recurrence: RecurrenceType.values.firstWhere(
        (r) => r.name == recurrenceRaw,
        orElse: () => RecurrenceType.none,
      ),
      description: json['description'] as String?,
      reminderMinutes: json['reminderMinutes'] as int? ?? 0,
      isAllDay: isAllDay,
      isFocusBlock: json['isFocusBlock'] as bool? ?? false,
      recurrenceUntil: DateTime.tryParse(json['recurrenceUntil'] as String? ?? ''),
    );
  }
}
