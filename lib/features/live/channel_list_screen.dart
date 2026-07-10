import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/focusable_button.dart';
import '../../data/models/models.dart';

/// A full-screen list of channels for a single group.
///
/// Used on narrow (phone) layouts when the user drills in from a group row in
/// [LiveScreen].
class ChannelListScreen extends StatelessWidget {
  const ChannelListScreen({
    super.key,
    required this.groupName,
    required this.channels,
    required this.onPlayChannel,
  });

  final String groupName;
  final List<Channel> channels;
  final void Function(List<Channel> channels, int index) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg2,
        title: Text(
          groupName,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: p.fg,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: channels.isEmpty
          ? Center(
              child: Text(
                'No channels',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: p.dim),
              ),
            )
          : ListView.builder(
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _ChannelRow(
                  channel: channel,
                  palette: p,
                  autofocus: index == 0,
                  onPlay: () => onPlayChannel(channels, index),
                );
              },
            ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.palette,
    required this.autofocus,
    required this.onPlay,
  });

  final Channel channel;
  final dynamic palette;
  final bool autofocus;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final p = palette as dynamic;
    return FocusableButton(
      autofocus: autofocus,
      semanticLabel: channel.name,
      onPressed: onPlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: p.border),
          ),
        ),
        child: Row(
          children: [
            // Logo circle / abbreviation
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.surface2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: channel.logoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        channel.logoUrl!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, st) =>
                            _Abbr(name: channel.name, palette: p),
                      ),
                    )
                  : _Abbr(name: channel.name, palette: p),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: p.fg,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            Icon(Icons.play_circle_outline_rounded, color: p.accent, size: 24),
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
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
