import 'package:flutter_test/flutter_test.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/core/recurrence.dart';
import 'package:hizli_not_alma_ve_gorev_listesi/features/tasks/models/repeat_rule.dart';

void main() {
  test('günlük tekrar bir gün ileri', () {
    final base = DateTime(2026, 6, 3);
    final next = nextDueDate(base, RepeatRule.daily);
    expect(next?.day, 4);
  });

  test('aylık tekrar ay sonuna kırpılır', () {
    expect(nextDueDate(DateTime(2026, 1, 31), RepeatRule.monthly), DateTime(2026, 2, 28));
  });

  test('tekrar yok null döner', () {
    expect(nextDueDate(DateTime.now(), RepeatRule.none), isNull);
  });
}
