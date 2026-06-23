import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../video_controller.dart';

/// UI state for the player screen.
class PlayerUiState extends Equatable {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool captionsOn;
  final bool showControls;
  final double volume;
  final bool muted;

  const PlayerUiState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.captionsOn = false,
    this.showControls = true,
    this.volume = 1.0,
    this.muted = false,
  });

  PlayerUiState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? captionsOn,
    bool? showControls,
    double? volume,
    bool? muted,
  }) =>
      PlayerUiState(
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        captionsOn: captionsOn ?? this.captionsOn,
        showControls: showControls ?? this.showControls,
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
      );

  @override
  List<Object?> get props => [isPlaying, position, duration, captionsOn, showControls, volume, muted];
}

/// Cubit managing all player interactions: playback, captions, progress saving.
class PlayerCubit extends Cubit<PlayerUiState> {
  final PlayerController _controller;
  final PlaybackRepository _playback;

  final String itemKey;
  final String url;
  final String title;
  final String? subtitle;
  final MediaKind kind;
  final String playlistId;

  StreamSubscription<PlayerStatus>? _statusSub;

  PlayerCubit(
    this._controller,
    this._playback, {
    required this.itemKey,
    required this.url,
    required this.title,
    this.subtitle,
    required this.kind,
    required this.playlistId,
  }) : super(const PlayerUiState());

  /// Initializes the player, seeks to resume position if available, and starts.
  Future<void> start() async {
    await _controller.initialize(url);

    final progress = await _playback.progressFor(itemKey);
    if (progress != null) {
      await _controller.seek(Duration(seconds: progress.positionSec));
    }

    await _controller.play();

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    _statusSub = _controller.status.listen((s) {
      emit(state.copyWith(
        isPlaying: s.isPlaying,
        position: s.position,
        duration: s.duration,
      ));
    });

    // Emit initial state from the controller
    emit(state.copyWith(
      isPlaying: _controller.isPlaying,
      position: _controller.position,
      duration: _controller.duration,
    ));
  }

  /// Toggles play/pause.
  Future<void> togglePlayPause() async {
    if (_controller.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
  }

  /// Skips forward 10 seconds, clamped to duration.
  Future<void> skipForward() async {
    final target = _controller.position + const Duration(seconds: 10);
    final clamped = _controller.duration > Duration.zero && target > _controller.duration
        ? _controller.duration
        : target;
    await _controller.seek(clamped);
  }

  /// Skips backward 10 seconds, clamped to zero.
  Future<void> skipBackward() async {
    final target = _controller.position - const Duration(seconds: 10);
    final clamped = target < Duration.zero ? Duration.zero : target;
    await _controller.seek(clamped);
  }

  /// Toggles caption display on/off.
  void toggleCaptions() {
    emit(state.copyWith(captionsOn: !state.captionsOn));
  }

  /// Sets the playback volume, clamped to [0.0, 1.0].
  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    await _controller.setVolume(clamped);
    emit(state.copyWith(volume: clamped));
  }

  double? _preMuteVolume;

  /// Toggles mute. Stores pre-mute volume on mute and restores on un-mute.
  Future<void> toggleMute() async {
    if (state.muted) {
      // Un-mute: restore saved volume
      final restored = _preMuteVolume ?? 1.0;
      _preMuteVolume = null;
      await _controller.setVolume(restored);
      emit(state.copyWith(volume: restored, muted: false));
    } else {
      // Mute: save current volume and set to 0
      _preMuteVolume = state.volume;
      await _controller.setVolume(0.0);
      emit(state.copyWith(muted: true));
    }
  }

  /// Seeks to the given position.
  Future<void> seekTo(Duration position) async {
    await _controller.seek(position);
  }

  Future<void> _saveProgress() async {
    await _playback.saveProgress(
      WatchProgress(
        itemKey: itemKey,
        playlistId: playlistId,
        kind: kind,
        positionSec: _controller.position.inSeconds,
        durationSec: _controller.duration.inSeconds,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> close() async {
    try {
      await _saveProgress();
      try {
        await WakelockPlus.disable();
      } catch (_) {}
      await _statusSub?.cancel();
    } finally {
      await _controller.dispose();
    }
    return super.close();
  }
}
