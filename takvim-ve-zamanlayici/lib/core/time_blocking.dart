import '../features/events/models/calendar_event.dart';

const focusBlockColorIndex = 4; // purple

CalendarEvent createFocusBlock({
  required DateTime start,
  required Duration duration,
  String title = 'Derin çalışma',
  String? description,
}) {
  final end = start.add(duration);
  return CalendarEvent(
    id: 'focus_${start.millisecondsSinceEpoch}',
    title: title,
    start: start,
    end: end,
    colorIndex: focusBlockColorIndex,
    description: description ?? 'Pomodoro odak bloğu',
    isFocusBlock: true,
  );
}

CalendarEvent createScheduledFocusBlock({
  required DateTime start,
  required int focusMinutes,
}) {
  return createFocusBlock(
    start: start,
    duration: Duration(minutes: focusMinutes),
  );
}
