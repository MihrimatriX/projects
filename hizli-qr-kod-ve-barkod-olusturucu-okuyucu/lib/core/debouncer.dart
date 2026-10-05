import 'dart:async';

/// Canlı QR önizleme için gecikmeli yenileme.
final class Debouncer {
  Debouncer({this.delayMs = 150});

  final int delayMs;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: delayMs), action);
  }

  void dispose() => _timer?.cancel();
}
