enum CalendarViewMode { month, week, day }

extension CalendarViewModeLabel on CalendarViewMode {
  String get label => switch (this) {
        CalendarViewMode.month => 'Ay',
        CalendarViewMode.week => 'Hafta',
        CalendarViewMode.day => 'Gün',
      };
}
