import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'focusable_button.dart';
import 'remote_image.dart';

/// A live channel as a logo tile — the shape Live TV uses, shared so channel
/// results in Search look the same as the channel grid they came from.
class ChannelTile extends StatelessWidget {
  const ChannelTile({
    super.key,
    required this.name,
    required this.number,
    required this.onPlay,
    this.logoUrl,
  });

  static const double width = 190.0;
  static const double height = 152.0;
  static const double spacing = 8.0;

  final String name;
  final String number;
  final String? logoUrl;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      semanticLabel: name,
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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: p.surface2,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: logoUrl != null
                  ? ClipOval(
                      child: RemoteImage(
                        url: logoUrl!,
                        width: 48,
                        height: 48,
                        memWidth: 144,
                        fallback: _Abbr(name: name),
                      ),
                    )
                  : _Abbr(name: name),
            ),
            const SizedBox(height: 6),
            // Flexible so the tile tolerates a few px less height (e.g. the
            // focus ring's inner padding) by ellipsizing instead of overflowing.
            Flexible(
              child: Text(
                name,
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
              number,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: p.dim),
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
