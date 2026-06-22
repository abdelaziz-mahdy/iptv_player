import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/features/onboarding/onboarding_screen.dart';

void main() {
  group('OnboardingScreen', () {
    Widget buildTestApp({required VoidCallback onGetStarted}) {
      return MaterialApp(
        theme: buildTheme(
          palette: AppPalette.standard,
          hyperlegible: false,
          rtl: false,
        ),
        home: OnboardingScreen(onGetStarted: onGetStarted),
      );
    }

    testWidgets('renders compliance text', (tester) async {
      await tester.pumpWidget(buildTestApp(onGetStarted: () {}));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'NOOR hosts no content. All channels and media come from playlists you provide.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders Get Started button', (tester) async {
      await tester.pumpWidget(buildTestApp(onGetStarted: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('tapping Get Started calls callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        buildTestApp(onGetStarted: () => called = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });
}
