import 'package:freezed_annotation/freezed_annotation.dart';

part 'accessibility_settings.freezed.dart';
part 'accessibility_settings.g.dart';

/// User accessibility preferences. Persisted by `AccessibilityCubit`.
///
/// Mirrors the accessibility panel in `design/ClearView IPTV.dc.html`:
/// text scaling, reduce motion, high contrast, colorblind-safe palette,
/// high-legibility font, and caption appearance (on/off, size, background
/// opacity, color).
@freezed
abstract class AccessibilitySettings with _$AccessibilitySettings {
  const factory AccessibilitySettings({
    @Default(1.0) double textScale, // 1.0 / 1.25 / 1.5
    @Default(false) bool reduceMotion,
    @Default(false) bool highContrast,
    @Default(false) bool colorblindSafe,
    @Default(false) bool hyperlegibleFont,
    @Default(false) bool captionsOn,
    @Default(24.0) double captionSize, // 18 / 24 / 32
    @Default(0.45) double captionBgOpacity, // 0 / 0.45 / 0.85
    @Default(0xFFFFFFFF) int captionColor, // white / yellow / cyan ARGB
  }) = _AccessibilitySettings;

  factory AccessibilitySettings.fromJson(Map<String, dynamic> json) =>
      _$AccessibilitySettingsFromJson(json);
}
