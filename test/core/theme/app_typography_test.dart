import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/theme/app_typography.dart';

void main() {
  test('text theme sets foreground color on body and headline', () {
    final t = buildTextTheme(
        fg: const Color(0xFFFFFFFF),
        dim: const Color(0xFF888888),
        hyperlegible: false,
        rtl: false);
    expect(t.bodyLarge!.color, const Color(0xFFFFFFFF));
    expect(t.headlineMedium!.color, const Color(0xFFFFFFFF));
    expect(t.bodyMedium!.color, const Color(0xFF888888));
  });

  test('headline uses a bold weight', () {
    final t = buildTextTheme(
        fg: Colors.white, dim: Colors.grey, hyperlegible: false, rtl: false);
    expect(t.headlineMedium!.fontWeight, FontWeight.w800);
  });

  test('rtl uses the Arabic family, hyperlegible overrides to Atkinson', () {
    final ar = buildTextTheme(fg: Colors.white, dim: Colors.grey, hyperlegible: false, rtl: true);
    expect(ar.bodyLarge!.fontFamily, 'IBMPlexSansArabic');
    final hl = buildTextTheme(fg: Colors.white, dim: Colors.grey, hyperlegible: true, rtl: true);
    expect(hl.bodyLarge!.fontFamily, 'AtkinsonHyperlegible');
  });
}
