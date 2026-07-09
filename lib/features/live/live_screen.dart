import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/a11y/accessibility_cubit.dart';
import '../../core/di/injection.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../core/widgets/live_badge.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/generated/app_localizations.dart';
import 'channel_list_screen.dart';
import 'cubit/live_cubit.dart';

/// Minimum width (logical pixels) for the wide (sidebar + grid) layout.
const double _kWideBreakpoint = 700.0;

/// Width of the left group-selector sidebar in wide layout.
const double _kSidebarWidth = 180.0;

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.onPlayChannel});

  final void Function(Channel) onPlayChannel;

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

class _LiveView extends StatelessWidget {
  const _LiveView({required this.onPlayChannel});

  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width >= _kWideBreakpoint;

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        backgroundColor: context.palette.bg2,
        title: Text(
          l10n.live,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: context.palette.fg,
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
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
            return Center(
              child: CircularProgressIndicator(
                color: context.palette.accent,
              ),
            );
          }

          if (state.groups.isEmpty) {
            return Center(
              child: Text(
                'No channels',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: context.palette.dim),
              ),
            );
          }

          if (isWide) {
            return _WideLayout(onPlayChannel: onPlayChannel);
          } else {
            return _NarrowLayout(onPlayChannel: onPlayChannel);
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
  const _WideLayout({required this.onPlayChannel});

  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveCubit, LiveState>(
      builder: (context, state) {
        final p = context.palette;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Sidebar: group list ----
            SizedBox(
              width: _kSidebarWidth,
              child: Container(
                color: p.bg2,
                child: ListView.builder(
                  itemCount: state.groups.length,
                  itemBuilder: (context, index) {
                    final group = state.groups[index];
                    final isSelected = group.id == state.selectedGroupId;
                    return _GroupTile(
                      group: group,
                      isSelected: isSelected,
                      autofocus: index == 0,
                      onTap: () => context.read<LiveCubit>().selectGroup(group.id),
                    );
                  },
                ),
              ),
            ),
            // Divider
            Container(width: 1, color: p.border),
            // ---- Channel grid ----
            Expanded(
              child: _ChannelGrid(
                channels: state.channelsInGroup,
                onPlayChannel: onPlayChannel,
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

  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveCubit, LiveState>(
      builder: (context, state) {
        final p = context.palette;
        return ListView.builder(
          itemCount: state.groups.length,
          itemBuilder: (context, index) {
            final group = state.groups[index];
            return FocusableButton(
              autofocus: index == 0,
              semanticLabel: group.name,
              onPressed: () {
                final cubit = context.read<LiveCubit>();
                cubit.selectGroup(group.id);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChannelListScreen(
                      groupName: group.name,
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
                        group.name,
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
                    Icon(Icons.chevron_right, color: p.dim, size: 20),
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

/// A group selector tile in the wide-layout sidebar.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.isSelected,
    required this.autofocus,
    required this.onTap,
  });

  final ChannelGroup group;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      autofocus: autofocus,
      semanticLabel: group.name,
      onPressed: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? p.accent.withValues(alpha: 0.18) : null,
          border: isSelected
              ? BorderDirectional(start: BorderSide(color: p.accent, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                group.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? p.accent : p.fg,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${group.count}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected ? p.accent : p.dim,
                    fontSize: 11,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid of channel tiles (logo / abbr + name + number).
class _ChannelGrid extends StatelessWidget {
  const _ChannelGrid({
    required this.channels,
    required this.onPlayChannel,
  });

  final List<Channel> channels;
  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No channels',
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: p.dim),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 120,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _ChannelTile(
          channel: channel,
          palette: p,
          onPlayChannel: onPlayChannel,
        );
      },
    );
  }
}

/// A single channel tile in the grid.
class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.palette,
    required this.onPlayChannel,
  });

  final Channel channel;
  final dynamic palette;
  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    final p = palette as dynamic;
    return FocusableButton(
      semanticLabel: channel.name,
      onPressed: () => onPlayChannel(channel),
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
                      child: Image.network(
                        channel.logoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, st) =>
                            _Abbr(name: channel.name, palette: p),
                      ),
                    )
                  : _Abbr(name: channel.name, palette: p),
            ),
            const SizedBox(height: 6),
            // Flexible so the tile tolerates a few px less height (e.g. the
            // focus ring's inner padding) by ellipsizing instead of overflowing.
            Flexible(
              child: Text(
                channel.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Abbr extends StatelessWidget {
  const _Abbr({required this.name, required this.palette});

  final String name;
  final dynamic palette;

  @override
  Widget build(BuildContext context) {
    final p = palette as dynamic;
    final abbr = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join()
        : '?';
    return Text(
      abbr.toUpperCase(),
      style: TextStyle(
        color: p.accent,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
