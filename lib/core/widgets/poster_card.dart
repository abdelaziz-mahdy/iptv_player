import 'package:flutter/material.dart';
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
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
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
                          backgroundColor: Colors.white24,
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
                      top: 6,
                      start: 6,
                      child: Semantics(
                        button: true,
                        label: isFavorite
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        child: GestureDetector(
                          onTap: onToggleFavorite,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: isFavorite ? p.accent : Colors.white,
                              size: 16,
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
