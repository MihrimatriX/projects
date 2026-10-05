import 'dart:math';

import '../features/tasks/models/repeat_rule.dart';
import 'date_utils.dart';

/// Tamamlanan tekrarlayan görev için bir sonraki son tarihi hesaplar.
DateTime? nextDueDate(DateTime? current, RepeatRule rule) {
  if (rule == RepeatRule.none) return null;
  final base = dateOnly(current ?? DateTime.now());
  return switch (rule) {
    // Takvim aritmetiği: Duration ile eklemek yaz saati geçişinde aynı güne düşebilir.
    RepeatRule.daily => DateTime(base.year, base.month, base.day + 1),
    RepeatRule.weekly => DateTime(base.year, base.month, base.day + 7),
    // 31 Ocak → 28/29 Şubat (taşıp Mart'a geçmesin diye ay sonuna kırpılır).
    RepeatRule.monthly => DateTime(base.year, base.month + 1,
        min(base.day, DateTime(base.year, base.month + 2, 0).day)),
    RepeatRule.none => null,
  };
}
