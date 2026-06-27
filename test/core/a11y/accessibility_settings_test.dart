import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/a11y/accessibility_settings.dart';

void main() {
  test('defaults match design baseline', () {
    const s = AccessibilitySettings();
    expect(s.textScale, 1.0);
    expect(s.reduceMotion, false);
    expect(s.captionSize, 24.0);
    expect(s.captionColor, 0xFFFFFFFF);
  });

  test('json round-trips', () {
    const s = AccessibilitySettings(highContrast: true, textScale: 1.5);
    expect(AccessibilitySettings.fromJson(s.toJson()), s);
  });
}
