import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';

void main() {
  test('theme uses palette bg as scaffold background and is dark', () {
    final theme = buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false);
    expect(theme.scaffoldBackgroundColor, AppPalette.standard.bg);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppPalette.standard.accent);
  });

  test('palette is exposed through the theme extension', () {
    final theme = buildTheme(palette: AppPalette.highContrast, hyperlegible: false, rtl: false);
    expect(theme.extension<PaletteExt>()!.palette.focus, AppPalette.highContrast.focus);
  });
}
