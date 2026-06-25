import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/features/details/details_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildTheme(
      palette: AppPalette.standard,
      hyperlegible: false,
      rtl: false,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  // -------------------------------------------------------------------------
  // Movie
  // -------------------------------------------------------------------------

  testWidgets('DetailsScreen.movie renders title and Play button', (tester) async {
    const movie = VodItem(
      id: 'm1',
      playlistId: 'p1',
      title: 'Dune',
      streamUrl: 'http://x',
    );

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.movie(
          movie,
          onBack: () {},
          onPlay: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Title is present
    expect(find.text('Dune'), findsAtLeast(1));

    // Play button text is present
    expect(find.text('Play'), findsAtLeast(1));
  });

  testWidgets('DetailsScreen.movie calls onPlay when Play button tapped',
      (tester) async {
    VodItem? played;
    const movie = VodItem(
      id: 'm2',
      playlistId: 'p1',
      title: 'Arrival',
      streamUrl: 'http://x',
    );

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.movie(
          movie,
          onBack: () {},
          onPlay: (v) => played = v,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap the first 'Play' text label
    await tester.tap(find.text('Play').first);
    await tester.pumpAndSettle();

    expect(played, equals(movie));
  });

  // -------------------------------------------------------------------------
  // Series
  // -------------------------------------------------------------------------

  testWidgets('DetailsScreen.series renders title and episode list after settle',
      (tester) async {
    const series = Series(
      id: 's1',
      playlistId: 'p1',
      title: 'Deep Field',
    );

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.series(
          series,
          onBack: () {},
          onPlayEpisode: (_) {},
        ),
      ),
    );

    // Allow cubit loadSeries to complete
    await tester.pumpAndSettle();

    // Series title is visible
    expect(find.text('Deep Field'), findsAtLeast(1));

    // Two seeded episodes should appear (offstage acceptable)
    expect(find.text('Pilot', skipOffstage: false), findsOneWidget);
    expect(find.text('Contact', skipOffstage: false), findsOneWidget);
  });

  testWidgets('DetailsScreen.series calls onPlayEpisode when episode tapped',
      (tester) async {
    Episode? played;
    const series = Series(id: 's1', playlistId: 'p1', title: 'Deep Field');

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.series(
          series,
          onBack: () {},
          onPlayEpisode: (e) => played = e,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Ensure the 'Pilot' text widget is scrolled into view
    await tester.ensureVisible(find.text('Pilot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilot'));
    await tester.pumpAndSettle();

    expect(played, isNotNull);
    expect(played!.title, 'Pilot');
  });

  testWidgets('DetailsScreen.series shows a Play button when episodes are loaded',
      (tester) async {
    const series = Series(id: 's1', playlistId: 'p1', title: 'Deep Field');

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.series(
          series,
          onBack: () {},
          onPlayEpisode: (_) {},
        ),
      ),
    );

    await tester.pumpAndSettle();

    // After episodes are loaded the series detail must have a Play button.
    expect(find.text('Play'), findsAtLeast(1));
  });

  testWidgets(
      'DetailsScreen.series Play button calls onPlayEpisode with first episode',
      (tester) async {
    Episode? played;
    const series = Series(id: 's1', playlistId: 'p1', title: 'Deep Field');

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.series(
          series,
          onBack: () {},
          onPlayEpisode: (e) => played = e,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The Play button (localized label) should be visible.
    final playFinder = find.text('Play');
    expect(playFinder, findsAtLeast(1));

    // Tap the first occurrence of Play (the primary series Play button).
    await tester.tap(playFinder.first);
    await tester.pumpAndSettle();

    // Should call back with the first episode (Pilot).
    expect(played, isNotNull);
    expect(played!.title, 'Pilot');
  });

  testWidgets('DetailsScreen.movie Play button has autofocus: true',
      (tester) async {
    const movie = VodItem(
      id: 'm3',
      playlistId: 'p1',
      title: 'Blade Runner',
      streamUrl: 'http://x',
    );

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.movie(
          movie,
          onBack: () {},
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Play FocusableButton should have autofocus: true.
    // There may be multiple FocusableButtons (back, play, my-list).
    // The play button is identifiable by its semantic label 'Play'.
    final playButtons = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.semanticLabel == 'Play',
    );
    expect(playButtons, findsOneWidget);
    expect(tester.widget<FocusableButton>(playButtons).autofocus, isTrue);
  });
}
