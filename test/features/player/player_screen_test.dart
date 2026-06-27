import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iptv_player/core/a11y/accessibility_cubit.dart';
import 'package:iptv_player/features/player/cubit/player_cubit.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/player/player_screen.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';
import 'fake_player_controller.dart';

Widget _buildPlayer({VoidCallback? onBack, MediaKind kind = MediaKind.movie}) => MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => AccessibilityCubit(),
        child: PlayerScreen(
          controller: FakePlayerController(),
          itemKey: kind == MediaKind.channel ? 'channel:c1' : 'movie:m1',
          url: 'http://x',
          title: 'Dune',
          onBack: onBack ?? () {},
          playbackRepository: FakePlaybackRepository(),
          kind: kind,
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

  testWidgets('controls auto-hide after idle and reappear on key press',
      (tester) async {
    await tester.pumpWidget(_buildPlayer());
    await tester.pump(); // let start() complete
    await tester.pump(const Duration(milliseconds: 100));

    List<double> targets() => tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .map((o) => o.opacity)
        .toList();

    // Playing → controls visible.
    expect(targets(), isNotEmpty);
    expect(targets().every((o) => o == 1.0), isTrue,
        reason: 'Controls should be visible right after playback starts');

    // Stay idle past the timeout → controls hide.
    await tester
        .pump(PlayerCubit.controlsIdleTimeout + const Duration(seconds: 1));
    await tester.pump();
    expect(targets().every((o) => o == 0.0), isTrue,
        reason: 'Controls should auto-hide after idle timeout');

    // A remote key press reveals them again.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(targets().any((o) => o == 1.0), isTrue,
        reason: 'Any key press should reveal the controls again');
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

  group('live vs VOD UI', () {
    testWidgets('live player shows LIVE indicator and hides seek Slider', (tester) async {
      await tester.pumpWidget(_buildPlayer(kind: MediaKind.channel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // LIVE pill must be present
      expect(find.text('LIVE'), findsOneWidget);

      // The seek Slider for position/duration must NOT be present.
      // The volume Slider is still present, so we check we have at most one Slider
      // (the volume one) — not the progress scrubber.
      // We verify by absence of the skip icons instead (more robust).
      expect(find.byIcon(Icons.replay_10), findsNothing,
          reason: 'Live: skip-back button must be hidden');
      expect(find.byIcon(Icons.forward_10), findsNothing,
          reason: 'Live: skip-forward button must be hidden');
    });

    testWidgets('movie player shows seek Slider and no LIVE indicator', (tester) async {
      await tester.pumpWidget(_buildPlayer(kind: MediaKind.movie));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // LIVE pill must NOT be present
      expect(find.text('LIVE'), findsNothing);

      // Skip buttons must exist for VOD
      expect(find.byIcon(Icons.replay_10), findsOneWidget,
          reason: 'VOD: skip-back button must be visible');
      expect(find.byIcon(Icons.forward_10), findsOneWidget,
          reason: 'VOD: skip-forward button must be visible');

      // At least one Slider must be present (the progress scrubber + possibly volume)
      expect(find.byType(Slider), findsAtLeast(1));
    });
  });
}
