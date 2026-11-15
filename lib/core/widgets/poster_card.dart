import 'package:material_ui/material_ui.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import 'focusable_button.dart';
import 'remote_image.dart';
import 'watch_labels.dart';

/// A 2:3 poster tile used across Home rails and grids: artwork with a gradient
/// scrim, optional badge and watch state, and a title/subtitle beneath.
///
/// Watch state is drawn to be read from across a room: a partly watched item
/// gets an 8 px bar along the poster's bottom edge with the time left above
/// it ([progress], [remainingSec]); a [watched] item is dimmed under a large
/// check and its subtitle reads "Watched".
///
/// When [onToggleFavorite] is provided, a small heart button is overlaid at the
/// top-start corner of the poster. [isFavorite] controls whether it appears
/// filled (favorited) or outlined. When [onToggleFavorite] is null the heart is
/// not rendered, and existing callers are completely unaffected.
class PosterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? badge;

  /// How far through the item the viewer is (0..1); null or 0 hides the bar.
  final double? progress;

  /// Seconds left to watch; shown as "38m left" above the bar when known.
  final int? remainingSec;

  /// Finished items get the dimmed poster and check instead of a bar.
  final bool watched;
  final VoidCallback? onTap;
  final bool isFavorite;
  final bool autofocus;
  final VoidCallback? onToggleFavorite;

  /// Widest the card draws; narrower when its grid tile is narrower.
  static const double width = 130;

  const PosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.badge,
    this.progress,
    this.remainingSec,
    this.watched = false,
    this.onTap,
    this.isFavorite = false,
    this.autofocus = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final fraction = progress ?? 0;
    final showBar = !watched && fraction > 0;
    final radius = BorderRadius.circular(10);
    return FocusableButton(
      semanticLabel: title,
      autofocus: autofocus,
      onPressed: onTap ?? () {},
      child: SizedBox(
        width: PosterCard.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: RemoteImage(url: imageUrl!, memWidth: 400),
                    ),
                  if (badge != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.scrim,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badge!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: p.onScrim,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  if (showBar)
                    Positioned.fill(
                      child: ClipRRect(
                        key: const Key('poster-progress'),
                        borderRadius: radius,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _ProgressFooter(
                            fraction: fraction.clamp(0.0, 1.0),
                            label: remainingSec == null
                                ? null
                                : timeLeftLabel(l10n, remainingSec!),
                          ),
                        ),
                      ),
                    ),
                  if (watched) ...[
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: radius,
                        child: ColoredBox(color: p.bg.withValues(alpha: 0.55)),
                      ),
                    ),
                    Center(
                      child: Container(
                        key: const Key('poster-watched'),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: p.onAccent,
                          size: 34,
                        ),
                      ),
                    ),
                  ],
                  // Heart favorite indicator — only rendered when wired up.
                  // Deliberately NOT a focus stop: D-pad grid navigation skips
                  // over it (toggled by touch/mouse, or via the details screen
                  // on a remote), so moving across the grid never lands on it.
                  if (onToggleFavorite != null)
                    PositionedDirectional(
                      top: -2,
                      start: -2,
                      child: Semantics(
                        button: true,
                        label: isFavorite
                            ? l10n.removeFromFavorites
                            : l10n.addToFavorites,
                        // 44x44 tap target around a 28px dot: the visual size
                        // suits the poster, the target meets the minimum.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onToggleFavorite,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: p.scrim,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite ? p.accent : p.onScrim,
                                  size: IconSize.sm,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (watched)
              Text(
                l10n.watched,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: p.accent, fontWeight: FontWeight.w600),
              )
            else if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

/// The bottom of an in-progress poster: "38m left" on a scrim that fades up
/// into the artwork, over a full-width 8 px bar flush with the poster edge.
class _ProgressFooter extends StatelessWidget {
  const _ProgressFooter({required this.fraction, required this.label});

  final double fraction;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.scrim.withValues(alpha: 0), p.scrim],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: p.onScrim, fontWeight: FontWeight.w700),
              ),
            ),
          SizedBox(
            height: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: p.onScrim.withValues(alpha: 0.35)),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction,
                  child: ColoredBox(color: p.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
