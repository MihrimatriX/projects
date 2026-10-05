import 'dart:async';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/downloads/downloads_provider.dart';
import '../../features/feeds/providers/feeds_provider.dart';
import '../network/podcast_http_provider.dart';
import '../settings/app_settings.dart';
import 'episode_chapter.dart';
import 'now_playing.dart';
import 'queue_provider.dart';
import 'smart_speed.dart';

/// Kullanıcıya olduğu gibi gösterilebilen oynatma hatası.
class PlaybackException implements Exception {
  const PlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

const playbackSpeeds = [0.8, 1.0, 1.2, 1.5, 1.8, 2.0];
const sleepDurations = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 60),
];

final playerProvider = NotifierProvider<PodcastPlayerNotifier, PodcastPlayerState>(
  PodcastPlayerNotifier.new,
);

class PodcastPlayerState {
  const PodcastPlayerState({
    this.nowPlaying,
    this.speed = 1.0,
    this.sleepEndsAt,
    this.smartSpeedActive = false,
  });

  final NowPlaying? nowPlaying;
  final double speed;
  final DateTime? sleepEndsAt;
  final bool smartSpeedActive;

  bool get hasTrack => nowPlaying != null;

  Duration? get sleepRemaining {
    if (sleepEndsAt == null) return null;
    final left = sleepEndsAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

class PodcastPlayerNotifier extends Notifier<PodcastPlayerState> {
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  Timer? _saveDebounce;
  Timer? _sleepTicker;
  Timer? _smartSpeedTicker;
  final _smartSpeed = SmartSpeedController();

  @override
  PodcastPlayerState build() {
    _player = AudioPlayer();
    ref.onDispose(_dispose);
    _positionSub = _player.positionStream.listen(_onPosition);
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
    _smartSpeedTicker = Timer.periodic(const Duration(milliseconds: 800), (_) => _tickSmartSpeed());
    ref.listen(appSettingsProvider, (_, next) {
      next.whenData((_) => applySmartSpeed());
    });
    return PodcastPlayerState(
      smartSpeedActive: ref.read(appSettingsProvider).value?.smartSpeedEnabled ?? false,
    );
  }

  void _dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _saveDebounce?.cancel();
    _sleepTicker?.cancel();
    _smartSpeedTicker?.cancel();
    _player.dispose();
  }

  AudioPlayer get player => _player;

  bool get _smartEnabled => ref.read(appSettingsProvider).value?.smartSpeedEnabled ?? false;

  Future<void> applySmartSpeed() async {
    final enabled = _smartEnabled;
    state = PodcastPlayerState(
      nowPlaying: state.nowPlaying,
      speed: state.speed,
      sleepEndsAt: state.sleepEndsAt,
      smartSpeedActive: enabled,
    );
    await _player.setSpeed(_smartSpeed.effectiveSpeed(state.speed, enabled));
  }

  void _tickSmartSpeed() async {
    if (!_smartEnabled || !_player.playing) return;
    final seekTo = _smartSpeed.nextSeek(
      playing: _player.playing,
      position: _player.position,
      duration: _player.duration,
    );
    if (seekTo != null) await _player.seek(seekTo);
  }

  // Konum en fazla 5 sn'de bir kaydedilir (throttle). positionStream oynatma
  // sırasında sürekli yayın yaptığı için önceki debounce hiç tetiklenmiyordu.
  void _onPosition(Duration position) {
    final track = state.nowPlaying;
    if (track == null) return;
    if (_saveDebounce?.isActive ?? false) return;
    _saveDebounce = Timer(const Duration(seconds: 5), () async {
      if (state.nowPlaying?.audioUrl != track.audioUrl) return;
      await ref.read(playbackPositionsProvider).save(
            track.audioUrl,
            _player.position,
            totalDuration: track.duration ?? _player.duration,
          );
    });
  }

  // Bölüm bitince önce "dinlendi" olarak işaretlenir, sonra sıradakine geçilir.
  Future<void> _onPlayerState(PlayerState ps) async {
    if (ps.processingState == ProcessingState.completed) {
      final done = state.nowPlaying;
      if (done != null) {
        await ref.read(playbackPositionsProvider).markCompleted(done.audioUrl);
      }
      await _playNextInQueue();
    }
  }

  Future<void> playEpisode({
    required String episodeTitle,
    required String audioUrl,
    required String podcastTitle,
    required String feedId,
    Duration? duration,
    String? localPath,
    List<EpisodeChapter> chapters = const [],
    String? imageUrl,
  }) async {
    final track = NowPlaying(
      episodeTitle: episodeTitle,
      audioUrl: audioUrl,
      podcastTitle: podcastTitle,
      feedId: feedId,
      duration: duration,
      localPath: localPath,
      imageUrl: imageUrl,
      chapters: chapters,
    );
    await _startTrack(track);
  }

  Future<void> playNowPlaying(NowPlaying track) => _startTrack(track);

  /// Çalan bölümün konumunu hemen kaydeder (5 sn'lik kayıt aralığını beklemeden).
  Future<void> _saveCurrentPosition() async {
    final track = state.nowPlaying;
    if (track == null) return;
    await ref.read(playbackPositionsProvider).save(
          track.audioUrl,
          _player.position,
          totalDuration: track.duration ?? _player.duration,
        );
  }

  Future<void> _startTrack(NowPlaying track) async {
    final positions = ref.read(playbackPositionsProvider);
    final downloads = ref.read(downloadServiceProvider);
    // Başka bölüme geçerken eskisinin son birkaç saniyesi kaybolmasın.
    if (state.nowPlaying?.audioUrl != track.audioUrl) await _saveCurrentPosition();
    try {
      final path = track.localPath ?? await downloads.localPathFor(track.audioUrl);
      if (path != null) {
        await _player.setFilePath(path);
      } else {
        final playbackUrl = ref.read(podcastHttpProvider).resolveUrl(track.audioUrl);
        await _player.setUrl(playbackUrl);
      }
      final saved = await positions.load(track.audioUrl);
      if (saved != null && saved.inSeconds > 0) {
        await _player.seek(saved);
      }
      _smartSpeed.reset();
      await applySmartSpeed();
      state = PodcastPlayerState(
        nowPlaying: track,
        speed: state.speed,
        sleepEndsAt: state.sleepEndsAt,
        smartSpeedActive: _smartEnabled,
      );
      await _player.play();
    } on MissingPluginException {
      throw const PlaybackException(
        'Bu platformda ses çalma desteklenmiyor (just_audio\'nun Windows eklentisi yok). '
        'Uygulamayı Chrome/Edge (web) sürümüyle kullan.',
      );
    } on PlayerException catch (e) {
      throw PlaybackException('Ses dosyası açılamadı: ${e.message ?? 'bağlantı ya da biçim hatası'}');
    } on PlayerInterruptedException {
      // Yükleme başka bir bölüm seçilerek kesildi; hata değil.
    }
  }

  Future<void> addToQueue(NowPlaying track) async {
    await ref.read(playQueueProvider.notifier).add(track, skipIfPlaying: false);
  }

  Future<void> _playNextInQueue() async {
    final queue = ref.read(playQueueProvider).value ?? [];
    if (queue.isEmpty) {
      await stop(clearSleep: false);
      return;
    }
    final next = queue.first;
    await ref.read(playQueueProvider.notifier).remove(next.audioUrl);
    try {
      await _startTrack(next);
    } catch (_) {
      // Sıradaki bölüm açılamadı (ör. çevrimdışı): yakalanmamış hata yerine dur.
      await stop(clearSleep: false);
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> seekBack15() async {
    final target = _player.position - const Duration(seconds: 15);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> seekForward30() async {
    final dur = _player.duration;
    if (dur == null) return;
    final target = _player.position + const Duration(seconds: 30);
    await _player.seek(target > dur ? dur : target);
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    state = PodcastPlayerState(
      nowPlaying: state.nowPlaying,
      speed: speed,
      sleepEndsAt: state.sleepEndsAt,
      smartSpeedActive: state.smartSpeedActive,
    );
    await applySmartSpeed();
  }

  Future<void> cycleSpeed() async {
    final idx = playbackSpeeds.indexOf(state.speed);
    final next = playbackSpeeds[(idx + 1) % playbackSpeeds.length];
    await setSpeed(next);
  }

  void startSleepTimer(Duration duration) {
    _sleepTicker?.cancel();
    final ends = DateTime.now().add(duration);
    state = PodcastPlayerState(
      nowPlaying: state.nowPlaying,
      speed: state.speed,
      sleepEndsAt: ends,
      smartSpeedActive: state.smartSpeedActive,
    );
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (state.sleepRemaining == Duration.zero) {
        _sleepTicker?.cancel();
        await _player.pause();
        state = PodcastPlayerState(
          nowPlaying: state.nowPlaying,
          speed: state.speed,
          smartSpeedActive: state.smartSpeedActive,
        );
      } else {
        state = PodcastPlayerState(
          nowPlaying: state.nowPlaying,
          speed: state.speed,
          sleepEndsAt: state.sleepEndsAt,
          smartSpeedActive: state.smartSpeedActive,
        );
      }
    });
  }

  void cancelSleepTimer() {
    _sleepTicker?.cancel();
    state = PodcastPlayerState(
      nowPlaying: state.nowPlaying,
      speed: state.speed,
      smartSpeedActive: state.smartSpeedActive,
    );
  }

  Future<void> stop({bool clearSleep = true}) async {
    await _saveCurrentPosition();
    await _player.stop();
    if (clearSleep) cancelSleepTimer();
    state = PodcastPlayerState(
      speed: state.speed,
      sleepEndsAt: state.sleepEndsAt,
      smartSpeedActive: state.smartSpeedActive,
    );
  }
}
