import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Açık kaydın duraklatma bilgisi. Uygulama duraklatılmışken kapanırsa açılışta
/// duraklatılmış olarak devam eder; aradaki süre kayda yazılmaz.
class PauseInfo {
  const PauseInfo({this.accum = Duration.zero, this.pausedAt});

  /// Tamamlanmış duraklatmaların toplamı.
  final Duration accum;

  /// null değilse şu an duraklatılmış.
  final DateTime? pausedAt;

  bool get paused => pausedAt != null;

  /// [now] anına kadar toplam duraklatma.
  Duration totalAt(DateTime now) => accum + (pausedAt == null ? Duration.zero : now.difference(pausedAt!));

  /// Duvar saatinden hesaplanan net süre: Timer tik sıklığı/gecikmesi sonucu etkilemez.
  Duration trackedAt(DateTime start, DateTime now) {
    final d = now.difference(start) - totalAt(now);
    return d.isNegative ? Duration.zero : d;
  }

  PauseInfo pause(DateTime now) => paused ? this : PauseInfo(accum: accum, pausedAt: now);

  PauseInfo resume(DateTime now) => paused ? PauseInfo(accum: totalAt(now)) : this;
}

class PauseStore {
  PauseStore(this._prefs);

  final SharedPreferences _prefs;
  static const storageKey = 'timer_pause';

  /// Yalnızca aynı kayda aitse döner; başka/eski kayıt için boş.
  PauseInfo load(int entryId) {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return const PauseInfo();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['entryId'] != entryId) return const PauseInfo();
      final at = j['pausedAt'];
      return PauseInfo(
        accum: Duration(milliseconds: j['accumMs'] as int? ?? 0),
        pausedAt: at is int ? DateTime.fromMillisecondsSinceEpoch(at) : null,
      );
    } catch (_) {
      return const PauseInfo();
    }
  }

  Future<void> save(int entryId, PauseInfo info) => _prefs.setString(
        storageKey,
        jsonEncode({
          'entryId': entryId,
          'accumMs': info.accum.inMilliseconds,
          if (info.pausedAt != null) 'pausedAt': info.pausedAt!.millisecondsSinceEpoch,
        }),
      );

  Future<void> clear() => _prefs.remove(storageKey);
}
