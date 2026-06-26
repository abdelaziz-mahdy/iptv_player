import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/a11y/accessibility_cubit.dart';
import 'package:noor_iptv/core/i18n/locale_cubit.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/features/settings/settings_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _buildTestApp(AccessibilityCubit a11y, LocaleCubit locale) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<AccessibilityCubit>.value(value: a11y),
      BlocProvider<LocaleCubit>.value(value: locale),
    ],
    child: MaterialApp(
      theme: buildTheme(
        palette: AppPalette.standard,
        hyperlegible: false,
        rtl: false,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ),
  );
}

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(
    tester.element(find.byType(SettingsScreen)),
  )!;
}

void main() {
  setUp(installFakeHydratedStorage);

  testWidgets('toggling High contrast flips AccessibilityCubit.state.highContrast',
      (tester) async {
    final a11y = AccessibilityCubit();
    final locale = LocaleCubit();

    await tester.pumpWidget(_buildTestApp(a11y, locale));
    await tester.pumpAndSettle();

    expect(a11y.state.highContrast, isFalse);

    final l10n = _l10n(tester);
    final switchFinder = find.ancestor(
      of: find.text(l10n.highContrast),
      matching: find.byType(SwitchListTile),
    );
    expect(switchFinder, findsOneWidget);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(a11y.state.highContrast, isTrue);
  });

  testWidgets('selecting text size Large sets textScale to 1.25', (tester) async {
    final a11y = AccessibilityCubit();
    final locale = LocaleCubit();

    await tester.pumpWidget(_buildTestApp(a11y, locale));
    await tester.pumpAndSettle();

    expect(a11y.state.textScale, 1.0);

    final l10n = _l10n(tester);
    await tester.tap(find.text(l10n.sizeLarge));
    await tester.pumpAndSettle();

    expect(a11y.state.textScale, 1.25);
  });

  testWidgets('compliance note text is present', (tester) async {
    final a11y = AccessibilityCubit();
    final locale = LocaleCubit();

    await tester.pumpWidget(_buildTestApp(a11y, locale));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(
      find.text(l10n.complianceNote, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('SettingsScreen has at least one autofocused FocusableButton',
      (tester) async {
    final a11y = AccessibilityCubit();
    final locale = LocaleCubit();
    await tester.pumpWidget(_buildTestApp(a11y, locale));
    await tester.pumpAndSettle();

    final autofocused = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    expect(autofocused, findsAtLeastNWidgets(1));
  });
}
