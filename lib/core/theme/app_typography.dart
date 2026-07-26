import 'package:flutter/material.dart';

/// Bundled font family names (declared in pubspec.yaml `flutter > fonts`).
const _hanken = 'HankenGrotesk';
const _arabic = 'IBMPlexSansArabic';
const _hyperlegible = 'AtkinsonHyperlegible';

/// Builds the app's [TextTheme].
///
/// Font choice follows the prototype: Hanken Grotesk for Latin UI, IBM Plex
/// Sans Arabic when the locale is RTL, and Atkinson Hyperlegible when the
/// high-legibility accessibility option is enabled (it wins over the others).
///
/// Fonts are bundled as assets (no runtime network fetch) so the app renders
/// correctly offline. Hanken Grotesk is a variable font, so its weight is
/// selected through the `wght` axis via [FontVariation].
TextTheme buildTextTheme({
  required Color fg,
  required Color dim,
  required bool hyperlegible,
  required bool rtl,
}) {
  TextStyle base(double size, FontWeight w, Color c) {
    if (hyperlegible) {
      return TextStyle(fontFamily: _hyperlegible, fontSize: size, fontWeight: w, color: c);
    }
    if (rtl) {
      return TextStyle(fontFamily: _arabic, fontSize: size, fontWeight: w, color: c);
    }
    return TextStyle(
      fontFamily: _hanken,
      fontSize: size,
      fontWeight: w,
      color: c,
      fontVariations: [FontVariation('wght', w.value.toDouble())],
    );
  }

  // Sizes are tuned for a 10-foot TV viewing distance. bodySmall/labelSmall
  // are defined here on purpose: undefined slots fall back to Material's
  // defaults (12/11 px) which are both unreadable across a room AND lose the
  // bundled font.
  return TextTheme(
    displayLarge: base(34, FontWeight.w800, fg),
    headlineMedium: base(24, FontWeight.w800, fg),
    titleLarge: base(18, FontWeight.w700, fg),
    bodyLarge: base(15, FontWeight.w500, fg),
    bodyMedium: base(14, FontWeight.w500, dim),
    bodySmall: base(14, FontWeight.w500, dim),
    labelLarge: base(13, FontWeight.w700, fg),
    labelMedium: base(13, FontWeight.w600, fg),
    labelSmall: base(13, FontWeight.w600, dim),
  );
}
