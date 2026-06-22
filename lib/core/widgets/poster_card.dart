import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'focusable_button.dart';

/// A 2:3 poster tile used across Home rails and grids: artwork with a gradient
/// scrim, optional badge and progress bar, and a title/subtitle beneath.
class PosterCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? badge;
  final double? progress;
  final VoidCallback onTap;
  const PosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.badge,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      semanticLabel: title,
      onPressed: onTap,
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
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
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
