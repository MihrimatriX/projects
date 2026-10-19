DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime? due) {
  if (due == null) return false;
  return isSameDay(dateOnly(due), dateOnly(DateTime.now()));
}

bool isOverdue(DateTime? due, {required bool done}) {
  if (due == null || done) return false;
  return dateOnly(due).isBefore(dateOnly(DateTime.now()));
}

bool isUpcoming(DateTime? due, {required bool done}) {
  if (due == null || done) return false;
  final today = dateOnly(DateTime.now());
  final d = dateOnly(due);
  return d.isAfter(today);
}
