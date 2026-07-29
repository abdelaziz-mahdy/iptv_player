/// Icon size scale. Sizes were being picked per call site (16/18/20/22/24/28…),
/// which reads as noise at a distance; pick the tier, not a number.
///
/// Tuned for a 10-foot TV viewing distance, so the tiers run larger than a
/// phone-first scale would.
abstract final class IconSize {
  /// Inline with body text — trailing chevrons, small affordances.
  static const double sm = 20;

  /// Default for controls and list rows.
  static const double md = 24;

  /// Primary actions: player transport, prominent buttons.
  static const double lg = 32;

  /// Empty-state and onboarding illustration glyphs.
  static const double xl = 56;
}
