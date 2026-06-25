import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/features/onboarding/onboarding_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

void main() {
  group('OnboardingScreen', () {
    Widget buildTestApp({required VoidCallback onGetStarted}) {
      return MaterialApp(
        theme: buildTheme(
          palette: AppPalette.standard,
          hyperlegible: false,
          rtl: false,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(onGetStarted: onGetStarted),
      );
    }

    AppLocalizations l10n(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(OnboardingScreen)))!;

    testWidgets('renders compliance text', (tester) async {
      await tester.pumpWidget(buildTestApp(onGetStarted: () {}));
      await tester.pumpAndSettle();

      expect(
        find.text(l10n(tester).complianceNote),
        findsOneWidget,
      );
    });

    testWidgets('renders Get Started button', (tester) async {
      await tester.pumpWidget(buildTestApp(onGetStarted: () {}));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).getStarted), findsOneWidget);
    });

    testWidgets('tapping Get Started calls callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        buildTestApp(onGetStarted: () => called = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n(tester).getStarted));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('Get Started button receives autofocus', (tester) async {
      await tester.pumpWidget(buildTestApp(onGetStarted: () {}));
      await tester.pumpAndSettle();

      // The FocusableButton wrapping Get Started should be the primary focus.
      final btn = find.byType(FocusableButton);
      expect(btn, findsOneWidget);
      expect(tester.widget<FocusableButton>(btn).autofocus, isTrue);
    });
  });
}
