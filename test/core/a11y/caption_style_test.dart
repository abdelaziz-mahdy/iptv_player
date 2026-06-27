import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/a11y/accessibility_settings.dart';
import 'package:iptv_player/core/a11y/caption_style.dart';

void main() {
  test('maps settings to caption style scaled by text scale', () {
    const s = AccessibilitySettings(
        captionSize: 32, captionBgOpacity: 0.85, captionColor: 0xFFFFE23D, textScale: 1.25);
    final cs = CaptionStyle.from(s);

    expect(cs.fontSize, 40); // 32 * 1.25
    expect(cs.textColor, const Color(0xFFFFE23D));
    expect(cs.backgroundColor.a, closeTo(0.85, 0.01));
    // Background base is black.
    expect(cs.backgroundColor.r, 0);
    expect(cs.backgroundColor.g, 0);
    expect(cs.backgroundColor.b, 0);
  });
}
