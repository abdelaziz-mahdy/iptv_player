import 'dart:async';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'video_controller.dart';

/// [PlayerController] backed by **media_kit** (real libmpv `vo_gpu` renderer).
///
/// Same demuxing power as fvp (both are libmpv-based), but mpv's renderer is
/// far more battle-tested across GPUs — used to evaluate devices where fvp/MDK
/// corrupts the video texture (e.g. some PowerVR TV chips).
class MediaKitPlayerController implements PlayerController {
  final Player _player = Player();
  late final VideoController videoController = VideoController(_player);

  final _statusCtrl = StreamController<PlayerStatus>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  double _volume = 1.0;

  /// mpv silently drops seeks issued before the media is loaded — this broke
  /// Continue Watching resume (PlayerCubit seeks right after initialize()).
  /// Early seeks are parked here and applied once the duration is known.
  Duration? _pendingSeek;

  void _emit() {
    if (_statusCtrl.isClosed) return;
    final s = _player.state;
    _statusCtrl.add(PlayerStatus(
      isPlaying: s.playing,
      position: s.position,
      duration: s.duration,
      buffering: s.buffering,
    ));
  }

  @override
  Future<void> initialize(String url) async {
    _subs.add(_player.stream.playing.listen((_) => _emit()));
    _subs.add(_player.stream.position.listen((_) => _emit()));
    _subs.add(_player.stream.duration.listen((d) {
      if (d > Duration.zero && _pendingSeek != null) {
        final target = _pendingSeek!;
        _pendingSeek = null;
        _player.seek(target);
      }
      _emit();
    }));
    _subs.add(_player.stream.buffering.listen((_) => _emit()));
    // Open without auto-play; PlayerCubit calls play() after seeking to resume.
    await _player.open(Media(url), play: false);
    _emit();
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) async {
    if (_player.state.duration == Duration.zero) {
      _pendingSeek = position;
      return;
    }
    await _player.seek(position);
  }

  @override
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _player.setVolume(_volume * 100); // media_kit volume is 0–100
  }

  @override
  double get volume => _volume;

  @override
  Stream<PlayerStatus> get status => _statusCtrl.stream;

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  bool get isPlaying => _player.state.playing;

  @override
  String? get streamBadge {
    final w = _player.state.width;
    final h = _player.state.height;
    if (w == null || h == null || w == 0 || h == 0) return null;
    return '$w×$h';
  }

  @override
  int? get currentBitRate => null; // not exposed by media_kit

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _statusCtrl.close();
    await _player.dispose();
  }
}
