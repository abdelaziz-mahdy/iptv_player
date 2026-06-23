import 'dart:async';

import 'package:noor_iptv/features/player/video_controller.dart';

class FakePlayerController implements PlayerController {
  final _statusCtrl = StreamController<PlayerStatus>.broadcast();
  bool _playing = false;
  Duration _position = Duration.zero;
  final Duration _duration = const Duration(minutes: 90);
  bool _initialized = false;
  double _volume = 1.0;

  // ignore: unused_field
  bool get initialized => _initialized;

  @override
  Future<void> initialize(String url) async {
    _initialized = true;
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

  void _emit() {
    if (!_statusCtrl.isClosed) {
      _statusCtrl.add(PlayerStatus(
        isPlaying: _playing,
        position: _position,
        duration: _duration,
        buffering: false,
      ));
    }
  }
}
