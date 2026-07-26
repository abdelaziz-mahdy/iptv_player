import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network image with an on-disk cache — every poster, backdrop and channel
/// logo goes through this. A raw `Image.network` re-downloads and re-decodes on
/// each pass over a long list, which is what a TV feels most.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
    this.memWidth,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Shown while loading and when the image fails, so the slot never jumps.
  final Widget? fallback;

  /// Decode width in pixels. Set it for thumbnails — providers often serve
  /// full-size artwork, and decoding that for a 48 px logo is pure waste.
  final int? memWidth;

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ?? const SizedBox.shrink();
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}
