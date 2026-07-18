import 'dart:async';
import 'dart:io' show Platform;

import 'package:equatable/equatable.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:video_player/video_player.dart';

/// Immutable snapshot of the player state.
class PlayerStatus extends Equatable {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool buffering;

  const PlayerStatus({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.buffering,
  });

  @override
  List<Object?> get props => [isPlaying, position, duration, buffering];
}

/// Abstract interface that all player backends implement.
abstract class PlayerController {
  /// Prepares [url] for playback. When [startAt] is given, playback begins
  /// at that position (resume) — backends apply it in the most reliable way
  /// they support (mpv: the `start` property at load; video_player: a seek
  /// after initialization).
  Future<void> initialize(String url, {Duration? startAt});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double v);
  double get volume;
  Stream<PlayerStatus> get status;
  Duration get position;
  Duration get duration;
  bool get isPlaying;

  /// Best-effort stream quality badge (e.g. resolution like "1280×720").
  ///
  /// Returns null until the video is initialized and size info is available.
  /// Note: real download-speed/bitrate is not exposed by the fvp-via-video_player
  /// abstraction, so this surfaces video resolution instead.
  String? get streamBadge;

  /// Real-time bitrate from fvp's [MediaInfo.bitRate] (bits per second).
  ///
  /// Returns null when unavailable (before init, or when fvp returns 0/throws).
  /// When playing, fvp updates this to the current network bitrate.
  int? get currentBitRate;

  Future<void> dispose();
}

/// Concrete adapter that wraps [VideoPlayerController] and registers fvp once.
class VideoPlayerControllerAdapter implements PlayerController {
  static bool _fvpRegistered = false;

  VideoPlayerController? _controller;
  final _statusCtrl = StreamController<PlayerStatus>.broadcast();
  bool _initialized = false;
  double _volume = 1.0;

  /// Whether the underlying [VideoPlayerController] is ready to render.
  bool get isInitialized => _initialized && _controller != null;

  /// The native [VideoPlayerController] — only valid after [initialize].
  VideoPlayerController get nativeController {
    assert(_controller != null, 'Call initialize() first');
    return _controller!;
  }

  @override
  Future<void> initialize(String url, {Duration? startAt}) async {
    if (!_fvpRegistered) {
      // fvp/MDK: the desktop player, and the Android backend under
      // FORCE_FVP=true. On Android TV PowerVR GPUs MDK's 10-bit EGLConfig
      // corrupts video — MainActivity sets EGL_SDR_DEPTH=8 (fvp#374) — and
      // the render size is capped near UI resolution: GL-rendering 4K RGBA
      // forces SurfaceFlinger into 4K GPU composition (~5 fps measured).
      // OpenSL audio: MDK slaves video pacing to the audio backend's position
      // clock, and this TV's AAudio reports positions too coarsely — frames
      // burst at ~10 presented fps. OpenSL paces frame-perfectly (24.2 fps,
      // zero droughts, benchmarked; fvp#384).
      fvp.registerWith(
          options: Platform.isAndroid
              ? {
                  'maxWidth': 1920,
                  'maxHeight': 1088,
                  'audioBackends': ['OpenSL'],
                }
              : null);
      _fvpRegistered = true;
    }

    // SurfaceView platform view on Android (own display layer, 2x presented
    // fps vs the texture path at capped 1080p, and the only surface type
    // that can show tunneled true-4K); texture path on desktop.
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      viewType: Platform.isAndroid
          ? VideoViewType.platformView
          : VideoViewType.textureView,
    );
    await _controller!.initialize();
    _initialized = true;
    if (startAt != null && startAt > Duration.zero) {
      await _controller!.seekTo(startAt);
    }

    _controller!.addListener(_onControllerUpdate);
    _emit();
  }

  void _onControllerUpdate() {
    _emit();
  }

  void _emit() {
    if (_statusCtrl.isClosed) return;
    final ctrl = _controller;
    if (ctrl == null) return;
    _statusCtrl.add(PlayerStatus(
      isPlaying: ctrl.value.isPlaying,
      position: ctrl.value.position,
      duration: ctrl.value.duration,
      buffering: ctrl.value.isBuffering,
    ));
  }

  @override
  Future<void> play() async {
    await _controller?.play();
  }

  @override
  Future<void> pause() async {
    await _controller?.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    await _controller?.seekTo(position);
  }

  @override
  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    await _controller?.setVolume(_volume);
  }

  @override
  double get volume => _volume;

  @override
  Stream<PlayerStatus> get status => _statusCtrl.stream;

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  @override
  String? get streamBadge {
    final size = _controller?.value.size;
    if (size == null || size.isEmpty) return null;
    return '${size.width.toInt()}×${size.height.toInt()}';
  }

  @override
  int? get currentBitRate {
    if (!_initialized || _controller == null) return null;
    try {
      // fvp extension on VideoPlayerController: getMediaInfo() returns MediaInfo
      // whose bitRate field is updated to the real-time value during playback.
      return _controller!.getMediaInfo()?.bitRate;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    _controller?.removeListener(_onControllerUpdate);
    await _statusCtrl.close();
    await _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}
