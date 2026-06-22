import 'dart:async';

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
  Stream<PlayerStatus> get status;
  Duration get position;
  Duration get duration;
  bool get isPlaying;
  Future<void> dispose();
}

/// Concrete adapter that wraps [VideoPlayerController] and registers fvp once.
class VideoPlayerControllerAdapter implements PlayerController {
  static bool _fvpRegistered = false;

  VideoPlayerController? _controller;
  final _statusCtrl = StreamController<PlayerStatus>.broadcast();
  bool _initialized = false;

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
      fvp.registerWith();
      _fvpRegistered = true;
    }

    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
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
  Stream<PlayerStatus> get status => _statusCtrl.stream;

  @override
  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  Duration get duration => _controller?.value.duration ?? Duration.zero;

  @override
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  @override
  Future<void> dispose() async {
    _controller?.removeListener(_onControllerUpdate);
    await _statusCtrl.close();
    await _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}
