/// Sessizlik atlama + hız çarpanı ile Smart Speed (Overcast tarzı yaklaşım).
class SmartSpeedController {
  Duration? _lastPosition;
  DateTime? _lastTick;
  int _slowTicks = 0;

  void reset() {
    _lastPosition = null;
    _lastTick = null;
    _slowTicks = 0;
  }

  /// Oynatma sırasında atlanacak yeni konum; yoksa null.
  Duration? nextSeek({
    required bool playing,
    required Duration position,
    required Duration? duration,
  }) {
    if (!playing) {
      reset();
      return null;
    }

    final now = DateTime.now();
    if (_lastPosition != null && _lastTick != null) {
      final wall = now.difference(_lastTick!);
      final advanced = position - _lastPosition!;
      if (wall.inMilliseconds >= 900 && advanced.inMilliseconds < 120) {
        _slowTicks++;
        if (_slowTicks >= 3) {
          _slowTicks = 0;
          const skip = Duration(seconds: 3);
          final end = duration ?? position + skip;
          if (position + skip < end - const Duration(seconds: 5)) {
            _lastPosition = position + skip;
            _lastTick = now;
            return position + skip;
          }
        }
      } else if (advanced.inMilliseconds >= 200) {
        _slowTicks = 0;
      }
    }

    _lastPosition = position;
    _lastTick = now;
    return null;
  }

  double effectiveSpeed(double userSpeed, bool enabled) {
    if (!enabled) return userSpeed;
    return (userSpeed * 1.2).clamp(0.8, 3.0);
  }
}
