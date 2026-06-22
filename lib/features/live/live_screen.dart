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
import 'cubit/live_cubit.dart';

/// Width of the sticky channel info column on the left.
const double _kChannelColWidth = 140.0;

/// Height of each channel row (EPG lane).
const double _kRowHeight = 72.0;

/// Height of the sticky time header row.
const double _kHeaderHeight = 36.0;

/// Width of one 30-minute slot in the time header / EPG lanes.
const double _kSlotWidth = 160.0;

/// Number of 30-minute slots to display (6 hours = 12 slots).
const int _kSlotCount = 12;

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.onPlayChannel});

  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LiveCubit(
        sl<ContentRepository>(),
        sl<EpgRepository>(),
        sl<PlaylistRepository>(),
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

          if (state.channels.isEmpty) {
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

          return _EpgGuide(
            channels: state.channels,
            epgByChannel: state.epgByChannel,
            onPlayChannel: onPlayChannel,
          );
        },
      ),
    );
  }
}

class _EpgGuide extends StatefulWidget {
  const _EpgGuide({
    required this.channels,
    required this.epgByChannel,
    required this.onPlayChannel,
  });

  final List<Channel> channels;
  final Map<String, List<EpgProgramme>> epgByChannel;
  final void Function(Channel) onPlayChannel;

  @override
  State<_EpgGuide> createState() => _EpgGuideState();
}

class _EpgGuideState extends State<_EpgGuide> {
  // Single horizontal scroll controller shared between time header and all lanes.
  final _hScroll = ScrollController();
  // Single vertical scroll controller for the channel rows.
  final _vScroll = ScrollController();

  late final DateTime _from;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _from = DateTime.utc(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      children: [
        // ---- Sticky header row (channel label + time slots) ----
        SizedBox(
          height: _kHeaderHeight,
          child: Row(
            children: [
              // Blank corner above channel column
              Container(
                width: _kChannelColWidth,
                color: p.bg2,
              ),
              // Scrollable time slots header
              Expanded(
                child: SingleChildScrollView(
                  controller: _hScroll,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: _TimeHeader(from: _from, palette: p),
                ),
              ),
            ],
          ),
        ),

        // ---- Channel rows ----
        Expanded(
          child: SingleChildScrollView(
            controller: _vScroll,
            child: Column(
              children: widget.channels.map((ch) {
                return _ChannelRow(
                  channel: ch,
                  programmes: widget.epgByChannel[ch.id] ?? [],
                  from: _from,
                  hScroll: _hScroll,
                  onPlayChannel: widget.onPlayChannel,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// The horizontal time-slot header ("18:00", "18:30", …).
class _TimeHeader extends StatelessWidget {
  const _TimeHeader({required this.from, required this.palette});

  final DateTime from;
  final dynamic palette;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: _kSlotCount * _kSlotWidth,
      child: Row(
        children: List.generate(_kSlotCount, (i) {
          final slotTime = from.add(Duration(minutes: 30 * i));
          final label =
              '${slotTime.hour.toString().padLeft(2, '0')}:${slotTime.minute.toString().padLeft(2, '0')}';
          return Container(
            width: _kSlotWidth,
            height: _kHeaderHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(
                right: BorderSide(color: p.border),
                bottom: BorderSide(color: p.border),
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: p.dim,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          );
        }),
      ),
    );
  }
}

/// One row: the sticky channel info cell + the horizontally scrollable EPG lane.
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.programmes,
    required this.from,
    required this.hScroll,
    required this.onPlayChannel,
  });

  final Channel channel;
  final List<EpgProgramme> programmes;
  final DateTime from;
  final ScrollController hScroll;
  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: _kRowHeight,
      child: Row(
        children: [
          // --- Sticky channel info cell ---
          FocusableButton(
            semanticLabel: channel.name,
            onPressed: () => onPlayChannel(channel),
            child: Container(
              width: _kChannelColWidth,
              height: _kRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: p.surface,
                border: Border(
                  right: BorderSide(color: p.border),
                  bottom: BorderSide(color: p.border),
                ),
              ),
              child: Row(
                children: [
                  // Logo abbreviation circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.surface2,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: channel.logoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              channel.logoUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (context2, err, st) =>
                                  _LogoAbbr(name: channel.name, palette: p),
                            ),
                          )
                        : _LogoAbbr(name: channel.name, palette: p),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          channel.name,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: p.fg,
                                    fontWeight: FontWeight.w600,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          channel.number,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: p.dim,
                                    fontSize: 10,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    channel.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: channel.isFavorite ? p.live : p.dim,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),

          // --- Horizontally scrollable EPG lane ---
          Expanded(
            child: SingleChildScrollView(
              controller: hScroll,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: _EpgLane(
                channel: channel,
                programmes: programmes,
                from: from,
                onPlayChannel: onPlayChannel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Abbreviation widget shown inside the logo circle when no logo URL is set.
class _LogoAbbr extends StatelessWidget {
  const _LogoAbbr({required this.name, required this.palette});

  final String name;
  final dynamic palette;

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
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// The per-channel horizontal lane of programme cells.
class _EpgLane extends StatelessWidget {
  const _EpgLane({
    required this.channel,
    required this.programmes,
    required this.from,
    required this.onPlayChannel,
  });

  final Channel channel;
  final List<EpgProgramme> programmes;
  final DateTime from;
  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final laneEnd = from.add(const Duration(minutes: 30 * _kSlotCount));
    final p = context.palette;

    // Build programme cells, filling any gaps with empty cells.
    final cells = <Widget>[];
    DateTime cursor = from;

    // Sort programmes by start time
    final sorted = [...programmes]
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));

    for (final prog in sorted) {
      final progStart = prog.startUtc.isBefore(from) ? from : prog.startUtc;
      final progEnd = prog.stopUtc.isAfter(laneEnd) ? laneEnd : prog.stopUtc;

      if (progStart.isAfter(laneEnd) || progEnd.isBefore(from)) continue;
      if (progStart.isAfter(cursor)) {
        // Gap filler
        final gapWidth = _minutesToWidth(
            progStart.difference(cursor).inMinutes.toDouble());
        cells.add(_ProgrammeCell(
          width: gapWidth,
          title: '',
          isOnNow: false,
          isEmpty: true,
          onTap: null,
          palette: p,
        ));
      }

      final cellWidth = _minutesToWidth(
          progEnd.difference(progStart).inMinutes.toDouble());
      final isOnNow =
          prog.startUtc.isBefore(now) && prog.stopUtc.isAfter(now);

      cells.add(_ProgrammeCell(
        width: cellWidth,
        title: prog.title,
        subtitle: prog.description,
        isOnNow: isOnNow,
        isEmpty: false,
        onTap: isOnNow ? () => onPlayChannel(channel) : null,
        palette: p,
      ));

      cursor = progEnd;
    }

    // Fill remaining lane after last programme
    if (cursor.isBefore(laneEnd)) {
      final tailWidth =
          _minutesToWidth(laneEnd.difference(cursor).inMinutes.toDouble());
      cells.add(_ProgrammeCell(
        width: tailWidth,
        title: '',
        isOnNow: false,
        isEmpty: true,
        onTap: null,
        palette: p,
      ));
    }

    return SizedBox(
      width: _kSlotCount * _kSlotWidth,
      height: _kRowHeight,
      child: Row(children: cells),
    );
  }

  double _minutesToWidth(double minutes) {
    return (minutes / 30.0) * _kSlotWidth;
  }
}

/// A single programme cell in the EPG lane.
class _ProgrammeCell extends StatelessWidget {
  const _ProgrammeCell({
    required this.width,
    required this.title,
    this.subtitle,
    required this.isOnNow,
    required this.isEmpty,
    required this.onTap,
    required this.palette,
  });

  final double width;
  final String title;
  final String? subtitle;
  final bool isOnNow;
  final bool isEmpty;
  final VoidCallback? onTap;
  final dynamic palette;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color bgColor;
    final Color borderColor;

    if (isEmpty) {
      bgColor = p.bg;
      borderColor = p.border;
    } else if (isOnNow) {
      bgColor = p.accent.withValues(alpha: 0.18);
      borderColor = p.accent;
    } else {
      bgColor = p.surface2;
      borderColor = p.border;
    }

    final cell = Container(
      width: width.clamp(0.0, double.infinity),
      height: _kRowHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor),
          bottom: BorderSide(color: p.border),
          left: isOnNow
              ? BorderSide(color: p.accent, width: 2)
              : BorderSide(color: borderColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (isOnNow) ...[
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                              color: isOnNow ? p.fg : p.dim,
                              fontWeight: isOnNow
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: p.dim,
                            fontSize: 10,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
    );

    if (onTap != null) {
      return FocusableButton(
        semanticLabel: title,
        onPressed: onTap!,
        child: cell,
      );
    }
    return cell;
  }
}
