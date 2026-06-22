import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Builds the app [ThemeData] for a given [palette].
///
/// The active [AppPalette] is exposed via [PaletteExt] so widgets can read
/// raw design tokens that don't map cleanly onto [ColorScheme] (e.g. `dim`,
/// `border`, `focus`, `live`).
ThemeData buildTheme({
  required AppPalette palette,
  required bool hyperlegible,
  required bool rtl,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: palette.accent,
    secondary: palette.accent2,
    surface: palette.surface,
    error: palette.live,
    onSurface: palette.fg,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    textTheme: buildTextTheme(fg: palette.fg, dim: palette.dim, hyperlegible: hyperlegible, rtl: rtl),
    dividerColor: palette.border,
    extensions: [PaletteExt(palette)],
  );
}

/// Theme extension carrying the full [AppPalette] for token access.
@immutable
class PaletteExt extends ThemeExtension<PaletteExt> {
  final AppPalette palette;
  const PaletteExt(this.palette);

  @override
  PaletteExt copyWith({AppPalette? palette}) => PaletteExt(palette ?? this.palette);

  @override
  PaletteExt lerp(ThemeExtension<PaletteExt>? other, double t) => this;
}

/// Convenience access to the active palette: `context.palette.accent`.
extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<PaletteExt>()!.palette;
}
