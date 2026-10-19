enum HabitFrequency { daily, weekly }

class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.icon = '🌱',
    this.color = 0xFF6366F1,
    this.frequency = HabitFrequency.daily,
    this.doneToday = false,
    this.streak = 0,
    this.lastCompletedDate,
    this.completionDates = const [],
    this.flexStreakEnabled = false,
    this.flexTargetPerWeek = 5,
    this.chainFromId,
  });

  final String id;
  final String title;
  final String icon;
  final int color;
  final HabitFrequency frequency;
  final bool doneToday;
  final int streak;
  final String? lastCompletedDate;
  final List<String> completionDates;
  /// Haftada [flexTargetPerWeek]/7 gün tamamlanınca seri korunur.
  final bool flexStreakEnabled;
  final int flexTargetPerWeek;
  /// Bu alışkanlık, [chainFromId] tamamlanınca hatırlatılır.
  final String? chainFromId;

  Habit copyWith({
    String? title,
    String? icon,
    int? color,
    HabitFrequency? frequency,
    bool? doneToday,
    int? streak,
    String? lastCompletedDate,
    List<String>? completionDates,
    bool? flexStreakEnabled,
    int? flexTargetPerWeek,
    String? chainFromId,
    bool clearChainFromId = false,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      frequency: frequency ?? this.frequency,
      doneToday: doneToday ?? this.doneToday,
      streak: streak ?? this.streak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      completionDates: completionDates ?? this.completionDates,
      flexStreakEnabled: flexStreakEnabled ?? this.flexStreakEnabled,
      flexTargetPerWeek: flexTargetPerWeek ?? this.flexTargetPerWeek,
      chainFromId: clearChainFromId ? null : (chainFromId ?? this.chainFromId),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'color': color,
        'frequency': frequency.name,
        'doneToday': doneToday,
        'streak': streak,
        'lastCompletedDate': lastCompletedDate,
        'completionDates': completionDates,
        'flexStreakEnabled': flexStreakEnabled,
        'flexTargetPerWeek': flexTargetPerWeek,
        'chainFromId': chainFromId,
      };

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id'] as String,
      title: json['title'] as String,
      icon: json['icon'] as String? ?? '🌱',
      color: json['color'] as int? ?? 0xFF6366F1,
      frequency: HabitFrequency.values.firstWhere(
        (f) => f.name == json['frequency'],
        orElse: () => HabitFrequency.daily,
      ),
      doneToday: json['doneToday'] as bool? ?? false,
      streak: json['streak'] as int? ?? 0,
      lastCompletedDate: json['lastCompletedDate'] as String?,
      completionDates: (json['completionDates'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      flexStreakEnabled: json['flexStreakEnabled'] as bool? ?? false,
      flexTargetPerWeek: json['flexTargetPerWeek'] as int? ?? 5,
      chainFromId: json['chainFromId'] as String?,
    );
  }
}

class ToggleResult {
  const ToggleResult({this.chainReminders = const []});

  final List<Habit> chainReminders;
}
