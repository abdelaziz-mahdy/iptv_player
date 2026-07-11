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
  Future<void> initialize(String url);
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
  Future<void> initialize(String url) async {
    if (!_fvpRegistered) {
      // fvp (MDK) is the player on ALL platforms. On Android TV PowerVR GPUs
      // MDK's default 10-bit EGLConfig corrupts video (fvp#374); MainActivity
      // sets EGL_SDR_DEPTH=8 before the engine loads to force the 8-bit
      // config. Default options let fvp pick per-platform hardware decoders.
      // Android: tunnel = MediaCodec renders directly into the SurfaceView
      // (platform view), scanned out by the TV's hardware video plane. The
      // GPU never touches the frames — required for 4K on this device, where
      // GL-rendered 4K RGBA forces SurfaceFlinger into 4K GPU composition
      // (~5 fps). Desktop keeps the default GL texture path.
      // Android: cap the video render size near the display's UI resolution.
      // This TV's GPU cannot GL-render + composite 4K RGBA (measured ~5 fps);
      // ≤1080p buffers ride the hardware scaler like the rest of the UI.
      // True-4K needs decoder→video-plane output (fvp tunnel), pending
      // upstream work. Desktop stays uncapped.
      // Android: cap the video render size near the display's UI resolution.
      // This TV's GPU cannot GL-render + composite 4K RGBA (measured ~5 fps);
      // ≤1080p buffers ride the hardware scaler like the rest of the UI.
      // True 4K would need tunneled decoder→video-plane output; MDK doesn't
      // accept a late tunnel surface yet (tracked upstream, wang-bin/fvp).
      fvp.registerWith(
          options: Platform.isAndroid
              ? {'maxWidth': 1920, 'maxHeight': 1088}
              : null);
      _fvpRegistered = true;
    }

    // platformView (SurfaceView) on Android: the video gets its own display
    // layer instead of passing through Flutter's compositor — measured 2×
    // the presented fps on the TV (21.5 vs 10.9 at capped 1080p), and it is
    // the only surface type that can ever show tunneled (true-4K) playback.
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      viewType: Platform.isAndroid
          ? VideoViewType.platformView
          : VideoViewType.textureView,
    );
    await _controller!.initialize();
    _initialized = true;

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
