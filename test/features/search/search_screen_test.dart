import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/features/search/cubit/search_cubit.dart';
import 'package:noor_iptv/features/search/search_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _buildTestApp({void Function(SearchEntry)? onOpen}) {
  return MaterialApp(
    theme: buildTheme(
      palette: AppPalette.standard,
      hyperlegible: false,
      rtl: false,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SearchScreen(onOpen: onOpen ?? (_) {}),
  );
}

/// Pump and settle while suppressing overflow errors from narrow test surface.
Future<void> _pumpAndIgnoreOverflow(
    WidgetTester tester, Widget widget) async {
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    prev?.call(details);
  };
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  FlutterError.onError = prev;
}

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('SearchScreen renders search text field', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets(
      'SearchScreen: entering "Dune" into the text field shows Dune result',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Dune', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
      'SearchScreen: tapping an on-screen key updates the query',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // The text field should be empty initially
    final textField =
        tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text ?? '', isEmpty);

    // Find and tap the 'D' key on the on-screen keyboard
    final dKeyFinder = find.widgetWithText(
      FocusableButton,
      'D',
      skipOffstage: false,
    );
    expect(dKeyFinder, findsAtLeastNWidgets(1));

    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      prev?.call(details);
    };
    await tester.tap(dKeyFinder.first);
    await tester.pumpAndSettle();
    FlutterError.onError = prev;

    // After tapping 'D' the query should be 'd' and results should update
    final updatedField =
        tester.widget<TextField>(find.byType(TextField));
    expect(updatedField.controller?.text, 'd');
  });

  testWidgets('SearchScreen: tapping a result calls onOpen', (tester) async {
    SearchEntry? opened;

    await _pumpAndIgnoreOverflow(
      tester,
      _buildTestApp(onOpen: (e) => opened = e),
    );

    // Type 'Dune' to get a result
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pumpAndSettle();

    // Find the PosterCard for Dune (it wraps in FocusableButton; tap that)
    final dunePoster = find.widgetWithText(
      FocusableButton,
      'Dune',
      skipOffstage: false,
    );
    expect(dunePoster, findsAtLeastNWidgets(1));

    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      prev?.call(details);
    };
    // The last FocusableButton with text 'Dune' is the PosterCard result
    // (the keyboard 'D' key is just 'D', not 'Dune')
    await tester.tap(dunePoster.last);
    await tester.pumpAndSettle();
    FlutterError.onError = prev;

    expect(opened, isNotNull);
    expect(opened!.title, 'Dune');
  });

  testWidgets('SearchScreen renders on-screen keyboard keys', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // Check a few keyboard keys are present
    expect(
      find.widgetWithText(FocusableButton, 'A', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.widgetWithText(FocusableButton, 'Z', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });
}
