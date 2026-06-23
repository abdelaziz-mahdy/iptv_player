import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../core/a11y/accessibility_cubit.dart';
import '../../core/a11y/accessibility_settings.dart';
import '../../core/a11y/caption_style.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
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
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  PlayerCubit? _cubit;

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
      );
      _cubit!.start();
    }
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Widget _buildVideoSurface() {
    if (widget.controller is VideoPlayerControllerAdapter) {
      final adapter = widget.controller as VideoPlayerControllerAdapter;
      if (adapter.isInitialized) {
        return VideoPlayer(adapter.nativeController);
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

    final isLive = _cubit!.isLive;

    return BlocProvider<PlayerCubit>.value(
      value: _cubit!,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocBuilder<PlayerCubit, PlayerUiState>(
          builder: (context, state) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // Video surface
                _buildVideoSurface(),

                // Top gradient + back + title
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
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
                          semanticLabel: 'Back',
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
                              size: 20,
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
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // Stream badge: resolution (best-effort; real bitrate not
                        // exposed by fvp-via-video_player)
                        if (state.streamBadge != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.palette.accent.withValues(alpha: 0.9),
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

                // Captions overlay
                if (state.captionsOn)
                  Positioned(
                    bottom: 96,
                    left: 32,
                    right: 32,
                    child: BlocBuilder<AccessibilityCubit, AccessibilitySettings>(
                      builder: (context, a11y) {
                        final cs = CaptionStyle.from(a11y);
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  child: Container(
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
                              alignment: Alignment.centerLeft,
                              child: _LivePill(),
                            ),
                          )
                        else
                          // VOD: full scrubber with position/duration labels
                          Row(
                            children: [
                              Text(
                                _formatDuration(state.position),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              Expanded(
                                child: Slider(
                                  value: state.duration.inMilliseconds > 0
                                      ? state.position.inMilliseconds
                                          .clamp(0, state.duration.inMilliseconds)
                                          .toDouble()
                                      : 0.0,
                                  min: 0,
                                  max: state.duration.inMilliseconds > 0
                                      ? state.duration.inMilliseconds.toDouble()
                                      : 1.0,
                                  onChanged: (value) {
                                    context.read<PlayerCubit>().seekTo(
                                          Duration(milliseconds: value.toInt()),
                                        );
                                  },
                                  activeColor: context.palette.accent,
                                  inactiveColor: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              Text(
                                _formatDuration(state.duration),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),

                        // Transport controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Skip backward 10s — VOD only
                            if (!isLive) ...[
                              FocusableButton(
                                semanticLabel: 'Skip backward 10 seconds',
                                onPressed: () => context.read<PlayerCubit>().skipBackward(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.replay_10, color: Colors.white, size: 28),
                                ),
                              ),
                              const SizedBox(width: 24),
                            ],
                            // Play/pause
                            FocusableButton(
                              semanticLabel: state.isPlaying ? 'Pause' : 'Play',
                              onPressed: () => context.read<PlayerCubit>().togglePlayPause(),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  state.isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                            // Skip forward 10s — VOD only
                            if (!isLive) ...[
                              const SizedBox(width: 24),
                              FocusableButton(
                                semanticLabel: 'Skip forward 10 seconds',
                                onPressed: () => context.read<PlayerCubit>().skipForward(),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.forward_10, color: Colors.white, size: 28),
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
                              semanticLabel: state.muted ? 'Unmute' : 'Mute',
                              onPressed: () => context.read<PlayerCubit>().toggleMute(),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  state.muted ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 24,
                                ),
                              ),
                            ),
                            // Volume slider (compact, desktop-friendly)
                            SizedBox(
                              width: 100,
                              child: Slider(
                                value: state.volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (v) => context.read<PlayerCubit>().setVolume(v),
                                activeColor: Colors.white,
                                inactiveColor: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // CC toggle
                            FocusableButton(
                              semanticLabel: state.captionsOn ? 'Captions on' : 'Captions off',
                              onPressed: () => context.read<PlayerCubit>().toggleCaptions(),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.closed_caption,
                                  color: state.captionsOn
                                      ? context.palette.accent
                                      : Colors.white.withValues(alpha: 0.6),
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Audio track button (placeholder)
                            FocusableButton(
                              semanticLabel: 'Audio track',
                              onPressed: () {},
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.audiotrack,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
