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
  final String? streamBadge;

  const PlayerUiState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.captionsOn = false,
    this.showControls = true,
    this.volume = 1.0,
    this.muted = false,
    this.streamBadge,
  });

  /// Sentinel used to distinguish "clear to null" from "leave unchanged" in
  /// [copyWith]. Pass [clearStreamBadge] instead of `streamBadge: null` when
  /// you want to remove the badge.
  static const _unset = Object();

  PlayerUiState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? captionsOn,
    bool? showControls,
    double? volume,
    bool? muted,
    // ignore: library_private_types_in_public_api
    Object? streamBadge = _unset,
  }) =>
      PlayerUiState(
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        captionsOn: captionsOn ?? this.captionsOn,
        showControls: showControls ?? this.showControls,
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
        streamBadge: identical(streamBadge, _unset)
            ? this.streamBadge
            : streamBadge as String?,
      );

  @override
  List<Object?> get props => [isPlaying, position, duration, captionsOn, showControls, volume, muted, streamBadge];
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
  Timer? _bitrateTimer;
  Timer? _controlsTimer;
  Timer? _progressTimer;

  /// How long the controls stay on screen after the last interaction before
  /// auto-hiding (only while playing).
  static const controlsIdleTimeout = Duration(seconds: 4);

  /// How often watch progress is persisted during playback. On a TV the app is
  /// usually killed/backgrounded without a clean [close], so relying on close()
  /// alone loses the position — we checkpoint periodically instead.
  static const progressSaveInterval = Duration(seconds: 10);

  PlayerCubit(
    this._controller,
    this._playback, {
    required this.itemKey,
    required this.url,
    required this.title,
    this.subtitle,
    required this.kind,
    required this.playlistId,
    this.recentKey,
  }) : super(const PlayerUiState());

  /// Browsable key recorded in "recently viewed" (e.g. `series:<id>` for an
  /// episode). Falls back to [itemKey] when null (movies/channels).
  final String? recentKey;

  /// Whether this is a live channel (not resumable VOD).
  bool get isLive => kind == MediaKind.channel;

  /// Formats a bitrate/resolution badge string from the controller's current data.
  ///
  /// Priority:
  ///   1. If [bitRate] is non-null and > 0 → format as Mbps (≥ 1 000 000) or Kbps.
  ///   2. If bitRate is 0 or null → fall back to [resolutionBadge] (e.g. "1280×720").
  ///   3. If neither is available → return null (no badge shown).
  static String? computeStreamBadge({required int? bitRate, required String? resolutionBadge}) {
    if (bitRate != null && bitRate > 0) {
      if (bitRate >= 1000000) {
        final mbps = bitRate / 1000000;
        return '${mbps.toStringAsFixed(1)} Mbps';
      } else {
        final kbps = bitRate ~/ 1000;
        return '$kbps Kbps';
      }
    }
    return resolutionBadge; // may be null
  }

  /// Initializes the player, seeks to resume position if available, and starts.
  Future<void> start() async {
    await _controller.initialize(url);

    if (!isLive) {
      final progress = await _playback.progressFor(itemKey);
      if (progress != null) {
        await _controller.seek(Duration(seconds: progress.positionSec));
      }
    }

    await _controller.play();

    // Record in "recently viewed" for ALL kinds (incl. live, which isn't saved
    // as resumable progress). Fire-and-forget — never block playback start.
    unawaited(_playback
        .recordView(playlistId: playlistId, itemKey: recentKey ?? itemKey)
        .catchError((_) {}));

    // Best-effort: keep the screen awake during playback. Fire-and-forget so
    // player setup never blocks on the platform channel.
    unawaited(WakelockPlus.enable().catchError((_) {}));

    _statusSub = _controller.status.listen((s) {
      if (isClosed) return;
      final wasPlaying = state.isPlaying;
      emit(state.copyWith(
        isPlaying: s.isPlaying,
        position: s.position,
        duration: s.duration,
        streamBadge: computeStreamBadge(
          bitRate: _controller.currentBitRate,
          resolutionBadge: _controller.streamBadge,
        ),
      ));
      // React only to actual play/pause transitions — not every position tick,
      // which would continuously reset the hide timer and never hide.
      if (s.isPlaying != wasPlaying) {
        if (s.isPlaying) {
          _scheduleHideControls();
        } else {
          // Keep controls visible while paused.
          _controlsTimer?.cancel();
          emit(state.copyWith(showControls: true));
        }
      }
    });

    // Poll bitrate every 2 seconds and update the stream badge.
    _bitrateTimer = Timer.periodic(const Duration(seconds: 2), (_) => _tickBitrate());

    // Checkpoint watch progress periodically so an abrupt TV kill/background
    // (no clean close) doesn't lose the position. Live channels are skipped
    // inside _saveProgress().
    if (!isLive) {
      _progressTimer =
          Timer.periodic(progressSaveInterval, (_) => _tickSaveProgress());
    }

    // Emit initial state from the controller
    emit(state.copyWith(
      isPlaying: _controller.isPlaying,
      position: _controller.position,
      duration: _controller.duration,
      streamBadge: computeStreamBadge(
        bitRate: _controller.currentBitRate,
        resolutionBadge: _controller.streamBadge,
      ),
    ));

    // Begin the idle countdown so controls auto-hide once playback is running.
    _scheduleHideControls();
  }

  /// Reveals the controls and (re)starts the idle countdown. Call on any user
  /// interaction (key press, tap, pointer move).
  void revealControls() {
    if (isClosed) return;
    if (!state.showControls) emit(state.copyWith(showControls: true));
    _scheduleHideControls();
  }

  /// Arms the idle timer to hide controls after [controlsIdleTimeout].
  /// Only auto-hides while playing — paused playback keeps controls visible.
  void _scheduleHideControls() {
    _controlsTimer?.cancel();
    if (!state.isPlaying) return;
    _controlsTimer = Timer(controlsIdleTimeout, () {
      if (!isClosed) emit(state.copyWith(showControls: false));
    });
  }

  /// Hides the controls immediately — **for testing only** (avoids waiting on
  /// the real idle [Timer]).
  void hideControlsForTesting() {
    if (!isClosed) emit(state.copyWith(showControls: false));
  }

  /// Samples [PlayerController.currentBitRate] and emits an updated badge.
  ///
  /// Called by [_bitrateTimer] every 2 seconds. Exposed as
  /// [pollBitrateBadgeForTesting] so unit tests can drive it directly without
  /// needing to control a real [Timer].
  void _tickBitrate() {
    if (isClosed) return;
    final badge = computeStreamBadge(
      bitRate: _controller.currentBitRate,
      resolutionBadge: _controller.streamBadge,
    );
    emit(state.copyWith(streamBadge: badge));
  }

  // ignore: invalid_annotation_target
  /// Triggers one poll tick — **for testing only**.
  // @visibleForTesting (avoids adding flutter dependency in cubit layer)
  void pollBitrateBadgeForTesting() => _tickBitrate();

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

  /// Periodic checkpoint driven by [_progressTimer]. Skips saving while the
  /// position is still zero (e.g. buffering, or before the resume seek lands)
  /// so a fresh tick can't clobber an existing resume point with 0.
  void _tickSaveProgress() {
    if (isClosed) return;
    if (_controller.position <= Duration.zero) return;
    unawaited(_saveProgress());
  }

  /// Forces one progress checkpoint immediately. Called when the app is
  /// backgrounded/paused (the common TV exit, where [close] may never run) and
  /// usable by tests to avoid waiting on the periodic [Timer].
  Future<void> saveProgressNow() => _saveProgress();

  Future<void> _saveProgress() async {
    if (isLive) return;
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
    _bitrateTimer?.cancel();
    _bitrateTimer = null;
    _controlsTimer?.cancel();
    _controlsTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
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
