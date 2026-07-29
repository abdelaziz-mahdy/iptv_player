import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import 'focusable_button.dart';
import 'remote_image.dart';

/// A 2:3 poster tile used across Home rails and grids: artwork with a gradient
/// scrim, optional badge and progress bar, and a title/subtitle beneath.
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
  final double? progress;
  final VoidCallback? onTap;
  final bool isFavorite;
  final bool autofocus;
  final VoidCallback? onToggleFavorite;
  const PosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.badge,
    this.progress,
    this.onTap,
    this.isFavorite = false,
    this.autofocus = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = AppLocalizations.of(context)!;
    return FocusableButton(
      semanticLabel: title,
      autofocus: autofocus,
      onPressed: onTap ?? () {},
      child: SizedBox(
        width: 130,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.scrim,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badge!,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: p.onScrim,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  if (progress != null)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: p.onScrim.withValues(alpha: 0.24),
                          valueColor: AlwaysStoppedAnimation(p.accent),
                        ),
                      ),
                    ),
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
            if (subtitle != null)
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
