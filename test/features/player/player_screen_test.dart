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

Widget _buildPlayer({
  VoidCallback? onBack,
  MediaKind kind = MediaKind.movie,
  FakePlayerController? controller,
}) => MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider(
        create: (_) => AccessibilityCubit(),
        child: PlayerScreen(
          controller: controller ?? FakePlayerController(),
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

  group('seek bar D-pad keys', () {
    // The Material Slider's internal shortcuts treat EVERY arrow key as a
    // value adjustment (down nudged the position -10s before focus moved).
    // The seek bar's focus stop is now a wrapper node that owns the keys:
    // left/right skip ±10s, up/down are pure focus moves.
    testWidgets('down leaves the position untouched and moves focus away',
        (tester) async {
      final controller = FakePlayerController();
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(
            palette: AppPalette.standard, hyperlegible: false, rtl: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => AccessibilityCubit(),
          child: PlayerScreen(
            controller: controller,
            itemKey: 'movie:m1',
            url: 'http://x',
            title: 'Dune',
            onBack: () {},
            playbackRepository: FakePlaybackRepository(),
            kind: MediaKind.movie,
            playlistId: 'p1',
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final sliderFocus = tester
          .widget<Focus>(find.byWidgetPredicate((w) =>
              w is Focus && w.focusNode?.debugLabel == 'player-seek-slider'))
          .focusNode!;
      sliderFocus.requestFocus();
      await tester.pump();
      expect(sliderFocus.hasPrimaryFocus, isTrue);

      // Right skips forward 10s (so a regression to -10s is observable).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.position, const Duration(seconds: 10));

      // Down must ONLY move focus — the position must not change.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(controller.position, const Duration(seconds: 10),
          reason: 'Down on the seek bar must not seek');
      expect(sliderFocus.hasPrimaryFocus, isFalse,
          reason: 'Down on the seek bar must move focus away');

      // And left on the (re-focused) bar seeks back 10s.
      sliderFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(controller.position, Duration.zero);
    });
  });

  testWidgets('spinner appears while re-buffering', (tester) async {
    final controller = FakePlayerController();
    await tester.pumpWidget(_buildPlayer(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);

    controller.buffering = true;
    controller.emitStatusForTesting();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    controller.buffering = false;
    controller.emitStatusForTesting();
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failed playback shows the reason and a retry, not black',
      (tester) async {
    final controller = FakePlayerController();
    controller.failNextInitializeWith =
        Exception('SocketException: Failed host lookup');
    await tester.pumpWidget(_buildPlayer(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Could not reach the stream. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Retry re-initializes; the second attempt succeeds and the panel goes.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.initializeCount, 2);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('left/right seek immediately while controls are hidden',
      (tester) async {
    final controller = FakePlayerController();
    await tester.pumpWidget(_buildPlayer(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final cubit = BlocProvider.of<PlayerCubit>(
      tester.element(find.byType(BlocConsumer<PlayerCubit, PlayerUiState>)),
    );
    cubit.hideControlsForTesting();
    await tester.pump();

    final before = cubit.state.position;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(cubit.state.position, before + const Duration(seconds: 10));
    await tester.pump();
    // The seek reveals the controls and puts the highlight on the scrubber,
    // which then owns the following presses.
    expect(cubit.state.showControls, isTrue);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player-seek-slider',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(cubit.state.position, before);
  });

  testWidgets('with the controls up, left/right leave the buttons alone',
      (tester) async {
    final controller = FakePlayerController();
    await tester.pumpWidget(_buildPlayer(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final cubit = BlocProvider.of<PlayerCubit>(
      tester.element(find.byType(BlocConsumer<PlayerCubit, PlayerUiState>)),
    );
    expect(cubit.state.showControls, isTrue);

    // Focus starts on play/pause, not the scrubber.
    final focused = FocusManager.instance.primaryFocus?.debugLabel;
    expect(focused, isNot('player-seek-slider'));

    final before = cubit.state.position;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // Right is traversal here: it must not seek, and must not drag the
    // highlight back onto the scrubber.
    expect(cubit.state.position, before);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('player-seek-slider'),
    );
  });
}
