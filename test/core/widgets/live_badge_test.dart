import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/live_badge.dart';

void main() {
  testWidgets('renders label and runs no animation ticker when reduceMotion', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: const Scaffold(body: LiveBadge(label: 'LIVE', reduceMotion: true)),
    ));
    expect(find.text('LIVE'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('runs an animation ticker when motion is allowed', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: const Scaffold(body: LiveBadge(label: 'LIVE')),
    ));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });
}
