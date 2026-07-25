import 'dart:async';

import 'package:iptv_player/features/player/video_controller.dart';

class FakePlayerController implements PlayerController {
  final _statusCtrl = StreamController<PlayerStatus>.broadcast();
  bool _playing = false;
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(minutes: 90);
  bool _initialized = false;
  double _volume = 1.0;

  /// Settable fake bitrate (bits/sec). Defaults to 4 200 000 (4.2 Mbps).
  /// Set to 0 to test the resolution fallback path. Set to null to test
  /// the "no info" path.
  @override
  int? currentBitRate = 4200000;

  // ignore: unused_field
  bool get initialized => _initialized;

  /// When set, [initialize] throws it — drives the failure/retry paths.
  /// Cleared automatically after one throw so a retry can succeed.
  Object? failNextInitializeWith;

  /// Emitted as [PlayerStatus.buffering] on every status tick.
  bool buffering = false;

  int initializeCount = 0;

  @override
  Future<void> initialize(String url, {Duration? startAt}) async {
    initializeCount++;
    final failure = failNextInitializeWith;
    if (failure != null) {
      failNextInitializeWith = null;
      throw failure;
    }
    _initialized = true;
    // Real backends begin playback at startAt (mpv `start` property / a
    // post-init seek) — mirror that so resume tests observe the position.
    if (startAt != null) {
      _position = startAt;
    }
    _emit();
  }

  @override
  Future<void> play() async {
    _playing = true;
    _emit();
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _emit();
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    _emit();
  }

  @override
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
  }

  @override
  double get volume => _volume;

  @override
  Stream<PlayerStatus> get status => _statusCtrl.stream;

  @override
  Duration get position => _position;

  @override
  Duration get duration => _duration;

  @override
  bool get isPlaying => _playing;

  @override
  String? get streamBadge => null;

  @override
  Future<void> dispose() async {
    await _statusCtrl.close();
  }

  /// Pushes one status tick with the current fake state — lets a test drive
  /// buffering transitions without touching playback.
  void emitStatusForTesting() => _emit();

  void _emit() {
    if (!_statusCtrl.isClosed) {
      _statusCtrl.add(PlayerStatus(
        isPlaying: _playing,
        position: _position,
        duration: _duration,
        buffering: buffering,
      ));
    }
  }
}
