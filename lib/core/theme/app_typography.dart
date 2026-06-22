import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds the app's [TextTheme].
///
/// Font choice follows the prototype: Hanken Grotesk for Latin UI, IBM Plex
/// Sans Arabic when the locale is RTL, and Atkinson Hyperlegible when the
/// high-legibility accessibility option is enabled (it wins over the others).
TextTheme buildTextTheme({
  required Color fg,
  required Color dim,
  required bool hyperlegible,
  required bool rtl,
}) {
  TextStyle base(double size, FontWeight w, Color c) {
    if (hyperlegible) {
      return GoogleFonts.atkinsonHyperlegible(fontSize: size, fontWeight: w, color: c);
    }
    if (rtl) {
      return GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: w, color: c);
    }
    return GoogleFonts.hankenGrotesk(fontSize: size, fontWeight: w, color: c);
  }

  return TextTheme(
    displayLarge: base(34, FontWeight.w800, fg),
    headlineMedium: base(24, FontWeight.w800, fg),
    titleLarge: base(18, FontWeight.w700, fg),
    bodyLarge: base(15, FontWeight.w500, fg),
    bodyMedium: base(14, FontWeight.w500, dim),
    labelLarge: base(13, FontWeight.w700, fg),
  );
}
