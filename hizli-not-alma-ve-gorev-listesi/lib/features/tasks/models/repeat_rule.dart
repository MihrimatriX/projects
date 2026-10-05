enum RepeatRule {
  none,
  daily,
  weekly,
  monthly;

  String? get storageKey => switch (this) {
        RepeatRule.none => null,
        RepeatRule.daily => 'daily',
        RepeatRule.weekly => 'weekly',
        RepeatRule.monthly => 'monthly',
      };

  static RepeatRule fromStorage(String? value) => switch (value) {
        'daily' => RepeatRule.daily,
        'weekly' => RepeatRule.weekly,
        'monthly' => RepeatRule.monthly,
        _ => RepeatRule.none,
      };

  String get label => switch (this) {
        RepeatRule.none => 'Tekrar yok',
        RepeatRule.daily => 'Her gün',
        RepeatRule.weekly => 'Her hafta',
        RepeatRule.monthly => 'Her ay',
      };
}
