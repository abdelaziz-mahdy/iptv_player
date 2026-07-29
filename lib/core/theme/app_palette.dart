import 'package:flutter/material.dart';

/// Color tokens for NOOR, taken verbatim from `design/ClearView IPTV.dc.html`.
///
/// Two palettes exist: the [standard] dark palette and the [highContrast]
/// palette used when the accessibility "high contrast" toggle is on.
@immutable
class AppPalette {
  final Color bg, bg2, surface, surface2, border, fg, dim, focus, accent, accent2, live;

  /// Text and icons drawn *on* an [accent] or [live] fill. Both are light
  /// enough to need dark ink; screens used to pick `Colors.black` or
  /// `Colors.white` by hand, which silently breaks if the accent changes.
  final Color onAccent;

  /// Overlay behind content that sits on artwork (poster badges, the heart
  /// button) — artwork is arbitrary, so these need their own scrim rather
  /// than a surface colour.
  final Color scrim;

  /// Text and icons on top of [scrim] or artwork.
  final Color onScrim;

  const AppPalette({
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.fg,
    required this.dim,
    required this.focus,
    required this.accent,
    required this.accent2,
    required this.live,
    this.onAccent = const Color(0xFF0A0D13),
    this.scrim = const Color(0x8C000000),
    this.onScrim = const Color(0xFFFFFFFF),
  });

  // Shared across both palettes.
  static const accentColor = Color(0xFFA78BFA); // violet
  static const accent2Color = Color(0xFF00E5FF);
  static const liveColor = Color(0xFFFF5252);

  static const standard = AppPalette(
    bg: Color(0xFF0A0D13),
    bg2: Color(0xFF10141D),
    surface: Color(0xFF171C28),
    surface2: Color(0xFF222A3B),
    border: Color(0x1CFFFFFF), // rgba(255,255,255,0.11)
    fg: Color(0xFFF3F6FB),
    dim: Color(0xFF97A3B7),
    focus: Color(0xFF5AB0FF),
    accent: accentColor,
    accent2: accent2Color,
    live: liveColor,
  );

  static const highContrast = AppPalette(
    bg: Color(0xFF000000),
    bg2: Color(0xFF000000),
    surface: Color(0xFF0C0C0C),
    surface2: Color(0xFF1C1C1C),
    border: Color(0xFFFFFFFF),
    fg: Color(0xFFFFFFFF),
    dim: Color(0xFFEAEAEA),
    focus: Color(0xFFFFE000),
    accent: accentColor,
    accent2: accent2Color,
    live: liveColor,
    onAccent: Color(0xFF000000),
    scrim: Color(0xE6000000),
  );
}
