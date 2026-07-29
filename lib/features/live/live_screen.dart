import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/a11y/accessibility_cubit.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_sizes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/category_sidebar.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/jump_to_letter.dart';
import '../../core/widgets/live_badge.dart';
import '../../core/widgets/remote_image.dart';
import '../../core/widgets/section_app_bar.dart';
import '../../core/widgets/status_views.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'channel_list_screen.dart';
import 'cubit/live_cubit.dart';

/// Display label for a group: the synthetic ones are localized here, since the
/// cubit has no BuildContext.
String _groupLabel(AppLocalizations l10n, ChannelGroup g) => switch (g.id) {
      kRecentGroupId => l10n.recentlyViewed,
      kAllGroupId => l10n.allCategory,
      kOtherGroupId => l10n.otherCategory,
      _ => g.name,
    };

/// Minimum width (logical pixels) for the wide (sidebar + grid) layout.
const double _kWideBreakpoint = 700.0;

/// Channel tile metrics — shared by the grid delegate and the letter jump,
/// which computes a scroll offset from them.
const double _kChannelTileWidth = 190.0;
const double _kChannelTileHeight = 152.0;
const double _kChannelTileSpacing = 8.0;

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.onPlayChannel});

  final void Function(List<Channel> channels, int index) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LiveCubit(
        sl<ContentRepository>(),
        sl<PlaylistRepository>(),
        playback: sl<PlaybackRepository>(),
      )..load(),
      child: _LiveView(onPlayChannel: onPlayChannel),
    );
  }
}

class _LiveView extends StatefulWidget {
  const _LiveView({required this.onPlayChannel});

  final void Function(List<Channel> channels, int index) onPlayChannel;

  @override
  State<_LiveView> createState() => _LiveViewState();
}

class _LiveViewState extends State<_LiveView> {
  final _gridController = ScrollController();

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  /// Scrolls the channel grid to the first channel starting with a letter the
  /// user picks. Tiles are a fixed size, so the offset is arithmetic — no need
  /// to build the intervening rows first.
  Future<void> _jumpToLetter(List<Channel> channels) async {
    final index = buildLetterIndex([for (final c in channels) c.name]);
    if (index.isEmpty) return;
    final letter = await showJumpToLetter(
      context,
      available: index.keys.toSet(),
      title: AppLocalizations.of(context)!.jumpToLetter,
    );
    final target = letter == null ? null : index[letter];
    if (target == null || !mounted || !_gridController.hasClients) return;

    final width = MediaQuery.sizeOf(context).width - CategorySidebar.width - 25;
    final columns = (width / _kChannelTileWidth).ceil().clamp(1, 100);
    final row = target ~/ columns;
    final offset = row * (_kChannelTileHeight + _kChannelTileSpacing);
    _gridController.jumpTo(
      offset.clamp(0.0, _gridController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width >= _kWideBreakpoint;

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: SectionAppBar(
        title: l10n.live,
        actions: [
          BlocBuilder<LiveCubit, LiveState>(
            builder: (context, state) {
              if (state.channelsInGroup.isEmpty) return const SizedBox.shrink();
              return FocusableButton(
                semanticLabel: l10n.jumpToLetter,
                onPressed: () => _jumpToLetter(state.channelsInGroup),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.sort_by_alpha,
                      color: context.palette.fg, size: IconSize.md),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: LiveBadge(
              label: 'LIVE',
              reduceMotion:
                  context.watch<AccessibilityCubit>().state.reduceMotion,
            ),
          ),
        ],
      ),
      body: BlocBuilder<LiveCubit, LiveState>(
        builder: (context, state) {
          if (state.loading) {
            return const LoadingState();
          }

          if (state.groups.isEmpty) {
            return EmptyState(
              icon: Icons.live_tv_outlined,
              message: l10n.noChannels,
            );
          }

          if (isWide) {
            return _WideLayout(
              onPlayChannel: widget.onPlayChannel,
              gridController: _gridController,
            );
          } else {
            return _NarrowLayout(onPlayChannel: widget.onPlayChannel);
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Wide layout: sidebar (groups) + channel grid
// ---------------------------------------------------------------------------

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.onPlayChannel, required this.gridController});

  final void Function(List<Channel> channels, int index) onPlayChannel;
  final ScrollController gridController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveCubit, LiveState>(
      builder: (context, state) {
        final p = context.palette;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategorySidebar(
              entries: [
                for (final g in state.groups)
                  (
                    id: g.id,
                    label: _groupLabel(AppLocalizations.of(context)!, g),
                    count: g.count,
                  ),
              ],
              selectedId: state.selectedGroupId,
              pinnedCount: state.pinnedGroupCount,
              onSelect: (id) => context.read<LiveCubit>().selectGroup(id),
            ),
            // Divider
            Container(width: 1, color: p.border),
            // ---- Channel grid ----
            Expanded(
              child: _ChannelGrid(
                channels: state.channelsInGroup,
                onPlayChannel: onPlayChannel,
                controller: gridController,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Narrow layout: group list; tap → ChannelListScreen
// ---------------------------------------------------------------------------

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.onPlayChannel});

  final void Function(List<Channel> channels, int index) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveCubit, LiveState>(
      builder: (context, state) {
        final p = context.palette;
        return ListView.builder(
          itemCount: state.groups.length,
          itemBuilder: (context, index) {
            final group = state.groups[index];
            final label = _groupLabel(AppLocalizations.of(context)!, group);
            return FocusableButton(
              autofocus: group.id == state.selectedGroupId,
              semanticLabel: label,
              onPressed: () {
                final cubit = context.read<LiveCubit>();
                cubit.selectGroup(group.id);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChannelListScreen(
                      groupName: label,
                      channels: cubit.state.channelsInGroup,
                      onPlayChannel: onPlayChannel,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: p.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: p.fg,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      '${group.count}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: p.dim),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: p.dim, size: IconSize.sm),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// Grid of channel tiles (logo / abbr + name + number).
class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
    required this.channels,
    required this.onPlayChannel,
    this.controller,
  });

  final List<Channel> channels;
  final void Function(List<Channel> channels, int index) onPlayChannel;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (channels.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noChannels,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: p.dim),
        ),
      );
    }
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _kChannelTileWidth,
        mainAxisExtent: _kChannelTileHeight,
        crossAxisSpacing: _kChannelTileSpacing,
        mainAxisSpacing: _kChannelTileSpacing,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _ChannelTile(
          channel: channel,
          onPlay: () => onPlayChannel(channels, index),
        );
      },
    );
  }
}

/// A single channel tile in the grid.
class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.onPlay,
  });

  final Channel channel;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      semanticLabel: channel.name,
      onPressed: onPlay,
      child: Container(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo circle / abbreviation
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: p.surface2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: channel.logoUrl != null
                  ? ClipOval(
                      child: RemoteImage(
                        url: channel.logoUrl!,
                        width: 48,
                        height: 48,
                        memWidth: 144,
                        fallback: _Abbr(name: channel.name),
                      ),
                    )
                  : _Abbr(name: channel.name),
            ),
            const SizedBox(height: 6),
            // Flexible so the tile tolerates a few px less height (e.g. the
            // focus ring's inner padding) by ellipsizing instead of overflowing.
            Flexible(
              child: Text(
                channel.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: p.fg,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              channel.number,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: p.dim,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Abbr extends StatelessWidget {
  const _Abbr({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final abbr = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join()
        : '?';
    return Text(
      abbr.toUpperCase(),
      style: TextStyle(
        color: p.accent,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
