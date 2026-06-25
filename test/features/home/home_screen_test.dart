import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/features/home/home_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _buildTestApp({
  void Function(VodItem)? onOpenMovie,
  void Function(Series)? onOpenSeries,
  VoidCallback? onAddPlaylist,
}) {
  return MaterialApp(
    theme: buildTheme(
      palette: AppPalette.standard,
      hyperlegible: false,
      rtl: false,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HomeScreen(
      onOpenMovie: onOpenMovie ?? (_) {},
      onOpenSeries: onOpenSeries ?? (_) {},
      onAddPlaylist: onAddPlaylist ?? () {},
    ),
  );
}

/// Pump the widget and suppress layout-overflow FlutterErrors.
Future<void> _pumpAndIgnoreOverflow(WidgetTester tester, Widget widget) async {
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

  testWidgets('HomeScreen renders a movie title from fakes', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    final titleFinder = find.textContaining(
      RegExp('The Signal|Dune'),
      skipOffstage: false,
    );
    expect(titleFinder, findsAtLeastNWidgets(1));
  });

  testWidgets('HomeScreen renders Movies rail', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    expect(find.text('Movies', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('HomeScreen renders Series rail', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    expect(find.text('Series', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('HomeScreen does NOT render Live TV rail', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // The Live TV rail has title 'Live' (from l10n.live).
    // We use skipOffstage: false to catch rails that are scrolled offscreen.
    expect(find.text('Live', skipOffstage: false), findsNothing);
  });

  testWidgets('HomeScreen tapping Play button triggers onOpenMovie',
      (tester) async {
    VodItem? tappedMovie;
    await _pumpAndIgnoreOverflow(
      tester,
      _buildTestApp(onOpenMovie: (m) => tappedMovie = m),
    );

    final playFinder = find.text('Play');
    expect(playFinder, findsAtLeastNWidgets(1));

    final previousHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previousHandler?.call(details);
    };
    await tester.tap(playFinder.first);
    await tester.pumpAndSettle();
    FlutterError.onError = previousHandler;

    expect(tappedMovie, isNotNull);
  });

  testWidgets('HomeScreen hero Play button has autofocus: true', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // The hero's Play FocusableButton should have autofocus.
    final playBtns = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    // At least one autofocused FocusableButton must exist.
    expect(playBtns, findsAtLeastNWidgets(1));
  });
}
