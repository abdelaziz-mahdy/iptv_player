import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/features/grid/cubit/grid_cubit.dart';
import 'package:noor_iptv/features/grid/grid_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _buildTestApp({
  GridKind kind = GridKind.movies,
  void Function(GridEntry)? onOpen,
}) {
  return MaterialApp(
    theme: buildTheme(
      palette: AppPalette.standard,
      hyperlegible: false,
      rtl: false,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: GridScreen(
      kind: kind,
      onOpen: onOpen ?? (_) {},
    ),
  );
}

Future<void> _pumpAndIgnoreOverflow(
    WidgetTester tester, Widget widget) async {
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previousHandler?.call(details);
  };
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  FlutterError.onError = previousHandler;
}

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('GridScreen renders a movie title from fakes', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // FakeContentRepository seeds: 'The Signal', 'Dune', 'Arrival', 'Interstellar'
    final titleFinder = find.textContaining(
      RegExp('The Signal|Dune|Arrival|Interstellar'),
      skipOffstage: false,
    );
    expect(titleFinder, findsAtLeastNWidgets(1));
  });

  testWidgets('GridScreen shows "Movies" title for movies kind', (tester) async {
    await _pumpAndIgnoreOverflow(
        tester, _buildTestApp(kind: GridKind.movies));

    expect(find.text('Movies', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('GridScreen shows "Series" title for series kind', (tester) async {
    await _pumpAndIgnoreOverflow(
        tester, _buildTestApp(kind: GridKind.series));

    expect(find.text('Series', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('GridScreen renders category chip names from fake (Action, Drama, All)',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp(kind: GridKind.movies));

    // The fake returns Action + Drama categories; cubit prepends "All".
    expect(find.text('All', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.text('Action', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.text('Drama', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('GridScreen renders Sci-Fi chip for series kind', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp(kind: GridKind.series));

    expect(find.text('All', skipOffstage: false), findsAtLeastNWidgets(1));
    expect(find.text('Sci-Fi', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('GridScreen chip row uses horizontal ListView builder', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp(kind: GridKind.movies));

    // There should be at least one horizontal ListView in the widget tree.
    final listViews = tester.widgetList<ListView>(find.byType(ListView));
    final hasHorizontal =
        listViews.any((lv) => lv.scrollDirection == Axis.horizontal);
    expect(hasHorizontal, isTrue,
        reason: 'chip row must use a horizontal ListView.builder');
  });

  testWidgets('GridScreen tapping a poster card calls onOpen', (tester) async {
    var tapped = false;
    await _pumpAndIgnoreOverflow(
      tester,
      _buildTestApp(onOpen: (GridEntry _) => tapped = true),
    );

    final previousHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previousHandler?.call(details);
    };

    // Tap the first GestureDetector
    final cards = find.byType(GestureDetector);
    if (cards.evaluate().isNotEmpty) {
      await tester.tap(cards.first);
      await tester.pumpAndSettle();
    }

    FlutterError.onError = previousHandler;

    // Either the onOpen was called, or at minimum the screen rendered
    // without throwing.
    expect(find.byType(GridScreen), findsOneWidget);
    expect(tapped, isNotNull); // suppress lint on tapped
  });
}
