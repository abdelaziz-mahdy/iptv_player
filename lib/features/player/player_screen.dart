import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../core/a11y/accessibility_cubit.dart';
import '../../core/a11y/accessibility_settings.dart';
import '../../core/a11y/caption_style.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'cubit/player_cubit.dart';
import 'video_controller.dart';

/// Small red "LIVE" pill shown in place of the seek scrubber for live channels.
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.live,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// Shown in place of the video when playback fails, so a dead stream reads as
/// an explained failure rather than a black screen.
class _PlayerError extends StatelessWidget {
  final PlaybackFailure failure;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _PlayerError({
    required this.failure,
    required this.onRetry,
    required this.onBack,
  });

  static String _message(AppLocalizations l10n, PlaybackFailure failure) =>
      switch (failure) {
        PlaybackFailure.network => l10n.playbackFailedNetwork,
        PlaybackFailure.unavailable => l10n.playbackFailedUnavailable,
        PlaybackFailure.refused => l10n.playbackFailedRefused,
        PlaybackFailure.timeout => l10n.playbackFailedTimeout,
        PlaybackFailure.unknown => l10n.playbackFailedUnknown,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: IconSize.xl,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                _message(l10n, failure),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FocusableButton(
                    autofocus: true,
                    onPressed: onRetry,
                    semanticLabel: l10n.retry,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(l10n.retry),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FocusableButton(
                    onPressed: onBack,
                    semanticLabel: l10n.back,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(l10n.back),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen video player.
///
/// Accepts a [PlayerController] (real or fake) and a [PlaybackRepository]
/// so it can be instantiated in tests without any DI container.
class PlayerScreen extends StatefulWidget {
  final PlayerController controller;
  final String itemKey;
  final String url;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final PlaybackRepository playbackRepository;
  final MediaKind kind;
  final String playlistId;

  /// Browsable key for "recently viewed" (e.g. `series:<id>` for an episode);
  /// null falls back to [itemKey].
  final String? recentKey;

  /// Move to the previous / next queue entry (previous episode in the season,
  /// previous channel in the group). Null hides the button — no queue, or at an
  /// end of the queue (no wrap-around).
  final VoidCallback? onPlayPrevious;
  final VoidCallback? onPlayNext;

  const PlayerScreen({
    super.key,
    required this.controller,
    required this.itemKey,
    required this.url,
    required this.title,
    this.subtitle,
    required this.onBack,
    required this.playbackRepository,
    required this.kind,
    required this.playlistId,
    this.recentKey,
    this.onPlayPrevious,
    this.onPlayNext,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  PlayerCubit? _cubit;

  // Root focus anchor: holds focus when the controls are hidden (and therefore
  // excluded from focus), so a D-pad press has no control to activate — the
  // first press only reveals the controls.
  final FocusNode _rootFocus = FocusNode(debugLabel: 'player-root');
  final FocusNode _sliderFocus = FocusNode(debugLabel: 'player-seek-slider');
  bool _sliderFocused = false;
  // Focus restored to the play/pause button each time controls are revealed.
  final FocusNode _playPauseFocus = FocusNode(debugLabel: 'player-playpause');
  // Set when a seek revealed the controls, so the reveal hands focus to the
  // scrubber instead of the play/pause button.
  bool _revealedBySeek = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Any key resets the idle timer (and reveals the controls if hidden),
    // regardless of which widget consumes the key. Consumes only the
    // left/right presses it turns into a seek — see [_handleHardwareKey].
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On TV, leaving the app (Home/recents) backgrounds it without a clean
    // dispose; checkpoint the position now so resume works after a kill.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _cubit?.saveProgressNow();
    }
  }

  /// Global key handler: any key wakes the controls and resets the idle timer,
  /// whichever widget ends up consuming the event.
  ///
  /// It also owns left/right *while the controls are hidden* — pressing up,
  /// landing on the scrubber and only then seeking is three presses for what a
  /// remote should do in one. That press seeks and moves focus onto the
  /// scrubber, so the highlight sits on the thing that is moving; every press
  /// after it is handled by the scrubber itself ([_onSliderKey]). Once the
  /// controls are visible it keeps its hands off: left/right are how the user
  /// moves between play/pause, skip and mute.
  ///
  /// It has to live here rather than in a Focus handler: it runs before focus
  /// dispatch, and afterwards "were the controls hidden?" can no longer be
  /// answered. Returns true only when it seeks, so nothing else acts on the
  /// same press.
  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final cubit = _cubit;
    if (cubit == null) return false;

    final key = event.logicalKey;
    final isSeekKey = key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    // Only while the controls are hidden. Once they are up, left/right belong
    // to focus traversal — otherwise every press from a button seeks and
    // yanks the highlight back to the scrubber, and the other controls can
    // never be reached.
    if (isSeekKey && !cubit.state.showControls && _seek(cubit, key)) {
      _revealedBySeek = true;
      cubit.revealControls();
      // Hidden controls sit behind ExcludeFocus, so the scrubber cannot take
      // focus until the reveal has been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sliderFocus.requestFocus();
      });
      return true;
    }
    cubit.revealControls();
    return false;
  }

  /// Seeks ±10s for left/right, RTL-aware like [_onSliderKey]. Live channels
  /// have nothing to seek in, and a failed or not-yet-started stream has no
  /// duration to seek within.
  bool _seek(PlayerCubit cubit, LogicalKeyboardKey key) {
    if (cubit.isLive ||
        cubit.state.error != null ||
        cubit.state.duration <= Duration.zero) {
      return false;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (key == LogicalKeyboardKey.arrowLeft) {
      rtl ? cubit.skipForward() : cubit.skipBackward();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      rtl ? cubit.skipBackward() : cubit.skipForward();
      return true;
    }
    return false;
  }

  /// D-pad handling for the seek bar. The Material [Slider] maps ALL arrow
  /// keys (incl. up/down) to value adjustments via its own internal
  /// Shortcuts, which always win over any outer handler — a "consumed"
  /// vertical arrow still nudged the value 10s before focus moved. So the
  /// slider itself is excluded from focus and this wrapper node owns the
  /// keys: left/right skip ±10s (RTL-aware, like the slider was), up/down
  /// are pure focus moves.
  KeyEventResult _onSliderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final cubit = _cubit;
    if (cubit == null) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      rtl ? cubit.skipForward() : cubit.skipBackward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      rtl ? cubit.skipBackward() : cubit.skipForward();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      node.focusInDirection(TraversalDirection.down);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      node.focusInDirection(TraversalDirection.up);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Wraps an overlay so it fades out and becomes non-interactive /
  /// non-focusable when [show] is false.
  Widget _hideable(bool show, Widget child) {
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !show,
        child: ExcludeFocus(excluding: !show, child: child),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cubit == null) {
      _cubit = PlayerCubit(
        widget.controller,
        widget.playbackRepository,
        itemKey: widget.itemKey,
        url: widget.url,
        title: widget.title,
        subtitle: widget.subtitle,
        kind: widget.kind,
        playlistId: widget.playlistId,
        recentKey: widget.recentKey,
      );
      _cubit!.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _rootFocus.dispose();
    _sliderFocus.dispose();
    _playPauseFocus.dispose();
    _cubit?.close();
    super.dispose();
  }

  Widget _buildVideoSurface() {
    final c = widget.controller;
    if (c is VideoPlayerControllerAdapter) {
      if (c.isInitialized) {
        // `VideoPlayer` has no fit of its own — it fills whatever constraints
        // it gets, and the parent Stack is StackFit.expand, so without an
        // AspectRatio the picture is stretched to the panel shape. Rebuild on
        // controller value changes: live streams can switch resolution
        // mid-play, and on Android the surface is a platform view that must be
        // re-laid-out when they do.
        final native = c.nativeController;
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: native,
          builder: (context, value, child) {
            final size = value.size;
            if (!value.isInitialized || size.width <= 0 || size.height <= 0) {
              return const ColoredBox(color: Colors.black);
            }
            return Center(
              child: AspectRatio(
                aspectRatio: size.width / size.height,
                child: child,
              ),
            );
          },
          child: VideoPlayer(native),
        );
      }
    }
    return const ColoredBox(color: Colors.black);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_cubit == null) {
      return const ColoredBox(color: Colors.black);
    }

    final l10n = AppLocalizations.of(context)!;
    final isLive = _cubit!.isLive;

    return BlocProvider<PlayerCubit>.value(
      value: _cubit!,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _rootFocus,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            // Pointer activity reveals controls and resets the idle timer.
            onPointerDown: (_) => _cubit?.revealControls(),
            onPointerHover: (_) => _cubit?.revealControls(),
            child: BlocConsumer<PlayerCubit, PlayerUiState>(
              // When controls reappear, move focus back onto a real control so
              // the D-pad works immediately.
              listenWhen: (prev, curr) =>
                  !prev.showControls && curr.showControls,
              listener: (context, state) {
                // A seek revealed them: focus belongs on the scrubber, which
                // it already has (see [_handleHardwareKey]).
                if (_revealedBySeek) {
                  _revealedBySeek = false;
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _playPauseFocus.requestFocus();
                });
              },
              builder: (context, state) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Video surface
                    _buildVideoSurface(),

                    // Opening / re-buffering spinner. Sits above the video so
                    // it also covers the black gap before the first frame.
                    if (state.loading && state.error == null)
                      const Center(
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    // Playback failed — say so instead of showing black.
                    if (state.error != null)
                      _PlayerError(
                        failure: state.error!,
                        onRetry: () => context.read<PlayerCubit>().retry(),
                        onBack: widget.onBack,
                      ),

                    // Top gradient + back + title
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _hideable(
                        state.showControls,
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(8, 40, 16, 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Back button
                              FocusableButton(
                                semanticLabel: l10n.back,
                                onPressed: widget.onBack,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                    size: IconSize.sm,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Title + subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (widget.subtitle != null)
                                      Text(
                                        widget.subtitle!,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              // Stream badge: real-time bitrate from fvp getMediaInfo()
                              // (e.g. "4.2 Mbps"), falling back to resolution string.
                              // Hidden when no info is available (streamBadge == null).
                              if (state.streamBadge != null)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      state.streamBadge!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              // HD quality badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: context.palette.accent.withValues(
                                    alpha: 0.9,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'HD',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Captions overlay
                    if (state.captionsOn)
                      Positioned(
                        bottom: 96,
                        left: 32,
                        right: 32,
                        child:
                            BlocBuilder<
                              AccessibilityCubit,
                              AccessibilitySettings
                            >(
                              builder: (context, a11y) {
                                final cs = CaptionStyle.from(a11y);
                                return Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    color: cs.backgroundColor,
                                    child: Text(
                                      '— Captions —',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: cs.textColor,
                                        fontSize: cs.fontSize,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),

                    // Bottom controls
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _hideable(
                        state.showControls,
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.9),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress / live row
                              if (isLive)
                                // Live channel: show LIVE pill instead of scrubber
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: _LivePill(),
                                  ),
                                )
                              else
                                // VOD: full scrubber with position/duration labels
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(state.position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Expanded(
                                      // The D-pad focus stop is this wrapper, not
                                      // the Slider: see _onSliderKey. Touch/mouse
                                      // still drag the slider directly; divisions
                                      // snap drags to 10s (tick marks hidden).
                                      child: Focus(
                                        focusNode: _sliderFocus,
                                        onKeyEvent: _onSliderKey,
                                        onFocusChange: (f) =>
                                            setState(() => _sliderFocused = f),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 120,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: _sliderFocused
                                                  ? context.palette.fg
                                                  : Colors.transparent,
                                              width: 3,
                                            ),
                                          ),
                                          child: ExcludeFocus(
                                            child: SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                    activeTickMarkColor:
                                                        Colors.transparent,
                                                    inactiveTickMarkColor:
                                                        Colors.transparent,
                                                  ),
                                              child: Slider(
                                                value:
                                                    state
                                                            .duration
                                                            .inMilliseconds >
                                                        0
                                                    ? state
                                                          .position
                                                          .inMilliseconds
                                                          .clamp(
                                                            0,
                                                            state
                                                                .duration
                                                                .inMilliseconds,
                                                          )
                                                          .toDouble()
                                                    : 0.0,
                                                min: 0,
                                                max:
                                                    state
                                                            .duration
                                                            .inMilliseconds >
                                                        0
                                                    ? state
                                                          .duration
                                                          .inMilliseconds
                                                          .toDouble()
                                                    : 1.0,
                                                divisions:
                                                    state.duration.inSeconds >=
                                                        10
                                                    ? state
                                                              .duration
                                                              .inSeconds ~/
                                                          10
                                                    : null,
                                                onChanged: (value) {
                                                  context
                                                      .read<PlayerCubit>()
                                                      .seekTo(
                                                        Duration(
                                                          milliseconds: value
                                                              .toInt(),
                                                        ),
                                                      );
                                                },
                                                activeColor:
                                                    context.palette.accent,
                                                inactiveColor: Colors.white
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(state.duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),

                              // Transport controls
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Previous episode / channel — only when a queue
                                  // neighbour exists on this side.
                                  if (widget.onPlayPrevious != null) ...[
                                    FocusableButton(
                                      semanticLabel: isLive
                                          ? 'Previous channel'
                                          : 'Previous episode',
                                      onPressed: widget.onPlayPrevious!,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.skip_previous,
                                          color: Colors.white,
                                          size: IconSize.lg,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                  ],
                                  // Skip backward 10s — VOD only
                                  if (!isLive) ...[
                                    FocusableButton(
                                      semanticLabel: l10n.skipBackward,
                                      onPressed: () => context
                                          .read<PlayerCubit>()
                                          .skipBackward(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.replay_10,
                                          color: Colors.white,
                                          size: IconSize.lg,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                  ],
                                  // Play/pause
                                  FocusableButton(
                                    focusNode: _playPauseFocus,
                                    autofocus: true,
                                    semanticLabel: state.isPlaying
                                        ? 'Pause'
                                        : 'Play',
                                    onPressed: () => context
                                        .read<PlayerCubit>()
                                        .togglePlayPause(),
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        state.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: IconSize.lg,
                                      ),
                                    ),
                                  ),
                                  // Skip forward 10s — VOD only
                                  if (!isLive) ...[
                                    const SizedBox(width: 24),
                                    FocusableButton(
                                      semanticLabel: l10n.skipForward,
                                      onPressed: () => context
                                          .read<PlayerCubit>()
                                          .skipForward(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.forward_10,
                                          color: Colors.white,
                                          size: IconSize.lg,
                                        ),
                                      ),
                                    ),
                                  ],
                                  // Next episode / channel — only when a queue
                                  // neighbour exists on this side.
                                  if (widget.onPlayNext != null) ...[
                                    const SizedBox(width: 24),
                                    FocusableButton(
                                      semanticLabel: isLive
                                          ? 'Next channel'
                                          : 'Next episode',
                                      onPressed: widget.onPlayNext!,
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.skip_next,
                                          color: Colors.white,
                                          size: IconSize.lg,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              const SizedBox(height: 8),

                              // Action row (right-aligned)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Mute / volume toggle
                                  FocusableButton(
                                    semanticLabel: state.muted
                                        ? 'Unmute'
                                        : 'Mute',
                                    onPressed: () => context
                                        .read<PlayerCubit>()
                                        .toggleMute(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        state.muted
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        size: IconSize.md,
                                      ),
                                    ),
                                  ),
                                  // Volume slider (desktop only). On Android/TV volume
                                  // is hardware-controlled, so the slider is just a
                                  // dead focus stop — the mute button stays.
                                  if (!Platform.isAndroid) ...[
                                    SizedBox(
                                      width: 100,
                                      child: Slider(
                                        value: state.volume,
                                        min: 0.0,
                                        max: 1.0,
                                        onChanged: (v) => context
                                            .read<PlayerCubit>()
                                            .setVolume(v),
                                        activeColor: Colors.white,
                                        inactiveColor: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // CC toggle
                                  FocusableButton(
                                    semanticLabel: state.captionsOn
                                        ? 'Captions on'
                                        : 'Captions off',
                                    onPressed: () => context
                                        .read<PlayerCubit>()
                                        .toggleCaptions(),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.closed_caption,
                                        color: state.captionsOn
                                            ? context.palette.accent
                                            : Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                        size: IconSize.md,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Audio track button (placeholder)
                                  FocusableButton(
                                    semanticLabel: l10n.audioTrack,
                                    onPressed: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.audiotrack,
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        size: IconSize.md,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
