import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/logging/app_logger.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../video_controller.dart';

/// Why playback could not start. Mapped to localized text by the screen.
enum PlaybackFailure {
  /// The provider/server could not be reached at all.
  network,

  /// The provider answered, but the stream is gone (404).
  unavailable,

  /// The provider rejected the request (401/403): subscription limits,
  /// too many connections, geo-block.
  refused,

  /// No answer in time.
  timeout,

  /// Anything else — the backend failed for a reason we cannot classify.
  unknown,
}

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

  /// Opening the stream, or re-buffering mid-playback — the screen shows a
  /// spinner. Distinct from [isPlaying] false, which is a deliberate pause.
  final bool loading;

  /// Playback could not start. When set, the screen shows the reason and a
  /// retry instead of a black rectangle.
  final PlaybackFailure? error;

  const PlayerUiState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.captionsOn = false,
    this.showControls = true,
    this.volume = 1.0,
    this.muted = false,
    this.streamBadge,
    this.loading = true,
    this.error,
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
    bool? loading,
    // ignore: library_private_types_in_public_api
    Object? error = _unset,
  }) => PlayerUiState(
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
    loading: loading ?? this.loading,
    error: identical(error, _unset) ? this.error : error as PlaybackFailure?,
  );

  @override
  List<Object?> get props => [
    isPlaying,
    position,
    duration,
    captionsOn,
    showControls,
    volume,
    muted,
    streamBadge,
    loading,
    error,
  ];
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

  /// Set once playback has actually produced motion, so the spinner is not
  /// shown again for a deliberate pause.
  bool _started = false;

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
  static String? computeStreamBadge({
    required int? bitRate,
    required String? resolutionBadge,
  }) {
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

  /// Classifies a start failure into a reason the screen can show in the
  /// user's language. The exception and stack trace go to the log, not to the
  /// screen — backend messages are developer text and often English-only.
  static PlaybackFailure classifyStartFailure(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('403') ||
        text.contains('401') ||
        text.contains('unauthor') ||
        text.contains('forbidden')) {
      return PlaybackFailure.refused;
    }
    if (text.contains('404') || text.contains('not found')) {
      return PlaybackFailure.unavailable;
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return PlaybackFailure.timeout;
    }
    if (text.contains('socket') ||
        text.contains('connection') ||
        text.contains('network') ||
        text.contains('host') ||
        text.contains('handshake')) {
      return PlaybackFailure.network;
    }
    return PlaybackFailure.unknown;
  }

  /// Retries after a failure — clears the error and runs [start] again.
  ///
  /// [start] wires up a status subscription and timers, so the previous set is
  /// torn down first; otherwise every retry would add another.
  Future<void> retry() async {
    if (isClosed || state.error == null) return;
    await _statusSub?.cancel();
    _statusSub = null;
    _bitrateTimer?.cancel();
    _bitrateTimer = null;
    _progressTimer?.cancel();
    _progressTimer = null;
    _started = false;
    emit(state.copyWith(loading: true, error: null, showControls: true));
    await start();
  }

  /// Initializes the player (resuming from saved progress) and starts.
  Future<void> start() async {
    // Resolve the resume position BEFORE initialize: backends apply it at
    // load (mpv's `start` property), which is reliable where a post-open
    // seek command is silently dropped (media-kit/media-kit#1215). A watched
    // item replays from the start instead of resuming at the final seconds.
    Duration? startAt;
    if (!isLive) {
      final progress = await _playback.progressFor(itemKey);
      if (progress != null && !progress.isWatched && progress.positionSec > 0) {
        startAt = Duration(seconds: progress.positionSec);
      }
    }

    // The play-attempt log is the forensic record for "this item won't play"
    // reports: origin is logged by the router, this line has the exact URL.
    appLog.info(
      'play ${kind.name} $itemKey resume=${startAt?.inSeconds ?? 0}s '
      'controller=${_controller.runtimeType} url=${scrubUrl(url)}',
    );

    try {
      await _controller.initialize(url, startAt: startAt);
      await _controller.play();
    } catch (e, st) {
      // Surfaced on screen rather than rethrown: an unhandled error here left
      // the player showing a black rectangle with no explanation.
      appLog.handle(e, st, 'player start failed for $itemKey');
      if (!isClosed) {
        emit(state.copyWith(loading: false, error: classifyStartFailure(e)));
      }
      return;
    }

    // Record in "recently viewed" for ALL kinds (incl. live, which isn't saved
    // as resumable progress). Fire-and-forget — never block playback start.
    unawaited(
      _playback
          .recordView(playlistId: playlistId, itemKey: recentKey ?? itemKey)
          .catchError((_) {}),
    );

    // Best-effort: keep the screen awake during playback. Fire-and-forget so
    // player setup never blocks on the platform channel.
    unawaited(WakelockPlus.enable().catchError((_) {}));

    _statusSub = _controller.status.listen((s) {
      if (isClosed) return;
      if (s.isPlaying || s.position > Duration.zero) _started = true;
      final wasPlaying = state.isPlaying;
      emit(
        state.copyWith(
          isPlaying: s.isPlaying,
          position: s.position,
          duration: s.duration,
          // Spinner while the backend re-buffers, and until playback has
          // actually begun — opening a stream can take seconds on a TV, and a
          // deliberate pause later must not bring the spinner back.
          loading: s.buffering || !_started,
          streamBadge: computeStreamBadge(
            bitRate: _controller.currentBitRate,
            resolutionBadge: _controller.streamBadge,
          ),
        ),
      );
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
    _bitrateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _tickBitrate(),
    );

    // Checkpoint watch progress periodically so an abrupt TV kill/background
    // (no clean close) doesn't lose the position. Live channels are skipped
    // inside _saveProgress().
    if (!isLive) {
      _progressTimer = Timer.periodic(
        progressSaveInterval,
        (_) => _tickSaveProgress(),
      );
    }

    // Emit initial state from the controller. The status ticks that fire
    // during initialize()/play() land before the subscription above exists,
    // so the spinner has to be resolved from the controller here too —
    // otherwise it hangs until the next tick.
    if (_controller.isPlaying || _controller.position > Duration.zero) {
      _started = true;
    }
    emit(
      state.copyWith(
        isPlaying: _controller.isPlaying,
        position: _controller.position,
        duration: _controller.duration,
        loading: !_started,
        streamBadge: computeStreamBadge(
          bitRate: _controller.currentBitRate,
          resolutionBadge: _controller.streamBadge,
        ),
      ),
    );

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
    final clamped =
        _controller.duration > Duration.zero && target > _controller.duration
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

  /// Periodic checkpoint driven by [_progressTimer].
  void _tickSaveProgress() {
    if (isClosed) return;
    unawaited(_saveProgress());
  }

  /// Forces one progress checkpoint immediately. Called when the app is
  /// backgrounded/paused (the common TV exit, where [close] may never run) and
  /// usable by tests to avoid waiting on the periodic [Timer].
  Future<void> saveProgressNow() => _saveProgress();

  Future<void> _saveProgress() async {
    if (isLive) return;
    // A zero position carries no resume information and would clobber an
    // existing resume point — e.g. backing out while the stream is still
    // buffering, before the resume seek has landed. Applies to the periodic
    // tick, the app-background save, and close() alike.
    if (_controller.position <= Duration.zero) return;
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
