import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';

void main() {
  test('standard palette matches design tokens', () {
    expect(AppPalette.standard.bg, const Color(0xFF0A0D13));
    expect(AppPalette.standard.surface, const Color(0xFF171C28));
    expect(AppPalette.standard.fg, const Color(0xFFF3F6FB));
    expect(AppPalette.standard.dim, const Color(0xFF97A3B7));
    expect(AppPalette.standard.focus, const Color(0xFF5AB0FF));
    expect(AppPalette.standard.accent, const Color(0xFFA78BFA));
    expect(AppPalette.standard.live, const Color(0xFFFF5252));
  });

  test('high-contrast palette matches design tokens', () {
    expect(AppPalette.highContrast.bg, const Color(0xFF000000));
    expect(AppPalette.highContrast.border, const Color(0xFFFFFFFF));
    expect(AppPalette.highContrast.fg, const Color(0xFFFFFFFF));
    expect(AppPalette.highContrast.focus, const Color(0xFFFFE000));
  });
}
