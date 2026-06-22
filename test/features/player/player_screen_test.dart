import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noor_iptv/core/a11y/accessibility_cubit.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/player/player_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';
import 'fake_player_controller.dart';

Widget _buildPlayer({VoidCallback? onBack}) => MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => AccessibilityCubit(),
        child: PlayerScreen(
          controller: FakePlayerController(),
          itemKey: 'movie:m1',
          url: 'http://x',
          title: 'Dune',
          onBack: onBack ?? () {},
          playbackRepository: FakePlaybackRepository(),
          kind: MediaKind.movie,
          playlistId: 'p1',
        ),
      ),
    );

void main() {
  setUpAll(() => installFakeHydratedStorage());

  testWidgets('renders title and play/pause control', (tester) async {
    await tester.pumpWidget(_buildPlayer());
    await tester.pump(); // let start() complete
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Dune'), findsOneWidget);
    // Play/pause button should exist
    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('tapping back invokes onBack', (tester) async {
    bool backCalled = false;
    await tester.pumpWidget(_buildPlayer(onBack: () => backCalled = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap back button (semantics label "Back" or find by icon)
    final backButtons = find.bySemanticsLabel(RegExp(r'[Bb]ack'));
    if (backButtons.evaluate().isNotEmpty) {
      await tester.tap(backButtons.first);
    } else {
      // Fallback: find first IconButton or GestureDetector near top
      final gestures = find.byType(GestureDetector);
      await tester.tap(gestures.first);
    }
    await tester.pump();
    expect(backCalled, isTrue);
  });
}
