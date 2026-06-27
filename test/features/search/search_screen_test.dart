import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/focusable_button.dart';
import 'package:iptv_player/features/search/cubit/search_cubit.dart';
import 'package:iptv_player/features/search/search_screen.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

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

void Function(FlutterErrorDetails)? _prevError;

void _suppressOverflow() {
  _prevError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    _prevError?.call(details);
  };
}

void _restoreOverflow() {
  FlutterError.onError = _prevError;
}

/// Pump and settle while suppressing overflow errors from narrow test surface.
Future<void> _pumpAndIgnoreOverflow(
    WidgetTester tester, Widget widget) async {
  _suppressOverflow();
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  _restoreOverflow();
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

  testWidgets('SearchScreen: on-screen keyboard is absent', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // QWERTY on-screen keyboard keys must not be present
    expect(find.text('Q'), findsNothing);
    expect(find.text('W'), findsNothing);
    expect(find.text('E'), findsNothing);
    expect(find.text('A'), findsNothing);
    expect(find.text('Z'), findsNothing);
  });

  testWidgets(
      'SearchScreen: entering "Dune" into the text field shows Dune result',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    _suppressOverflow();
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pumpAndSettle();
    _restoreOverflow();

    expect(
      find.textContaining('Dune', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
      'SearchScreen: no on-screen keyboard keys while typing shows result',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // Keyboard keys must be absent before typing
    expect(find.text('Q'), findsNothing);

    _suppressOverflow();
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pumpAndSettle();
    _restoreOverflow();

    // Still no keyboard keys after typing
    expect(find.text('Q'), findsNothing);

    // But the Dune result is shown
    expect(
      find.textContaining('Dune', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('SearchScreen: tapping a result calls onOpen', (tester) async {
    SearchEntry? opened;

    await _pumpAndIgnoreOverflow(
      tester,
      _buildTestApp(onOpen: (e) => opened = e),
    );

    // Type 'Dune' to get a result
    _suppressOverflow();
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pumpAndSettle();
    _restoreOverflow();

    // Find the PosterCard for Dune (it wraps in FocusableButton; tap that)
    final dunePoster = find.widgetWithText(
      FocusableButton,
      'Dune',
      skipOffstage: false,
    );
    expect(dunePoster, findsAtLeastNWidgets(1));

    _suppressOverflow();
    await tester.tap(dunePoster.first);
    await tester.pumpAndSettle();
    _restoreOverflow();

    expect(opened, isNotNull);
    expect(opened!.title, 'Dune');
  });

  testWidgets(
      'SearchScreen: TextField has autofocus enabled',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.autofocus, isTrue);
  });

  testWidgets(
      'SearchScreen: typing "Dune" shows a Movies section label',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    _suppressOverflow();
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pumpAndSettle();
    _restoreOverflow();

    // The "Movies" section header must be present.
    expect(
      find.textContaining('Movies', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
      'SearchScreen: typing "Dune" shows the Dune card in a horizontal rail',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    _suppressOverflow();
    await tester.enterText(find.byType(TextField), 'Dune');
    await tester.pumpAndSettle();
    _restoreOverflow();

    // Results are rendered in horizontal ListViews (rails), not a GridView.
    expect(find.byType(GridView), findsNothing);
    expect(
      find.textContaining('Dune', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
      'SearchScreen: searching "horizon" shows a Series section label',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    _suppressOverflow();
    await tester.enterText(find.byType(TextField), 'horizon');
    await tester.pumpAndSettle();
    _restoreOverflow();

    expect(
      find.textContaining('Series', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
      'SearchScreen: empty query shows no rails',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // No text entered — no section labels should appear.
    expect(find.text('Movies'), findsNothing);
    expect(find.text('Series'), findsNothing);
  });
}
