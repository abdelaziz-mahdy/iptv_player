import 'package:flutter/material.dart';
import 'accessibility_settings.dart';

/// Resolved caption appearance derived from [AccessibilitySettings].
///
/// Font size is scaled by the global text-scale factor; the background is
/// black at the configured opacity; text uses the configured color.
@immutable
class CaptionStyle {
  final double fontSize;
  final Color textColor;
  final Color backgroundColor;

  const CaptionStyle({
    required this.fontSize,
    required this.textColor,
    required this.backgroundColor,
  });

  factory CaptionStyle.from(AccessibilitySettings s) => CaptionStyle(
        fontSize: s.captionSize * s.textScale,
        textColor: Color(s.captionColor),
        backgroundColor: Colors.black.withValues(alpha: s.captionBgOpacity),
      );
}
