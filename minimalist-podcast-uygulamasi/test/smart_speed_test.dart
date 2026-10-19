import 'package:flutter_test/flutter_test.dart';
import 'package:minimalist_podcast_uygulamasi/core/player/smart_speed.dart';

void main() {
  test('effective speed boosts when enabled', () {
    final c = SmartSpeedController();
    expect(c.effectiveSpeed(1.0, true), greaterThan(1.0));
    expect(c.effectiveSpeed(1.0, false), 1.0);
  });
}
