import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/features/player/cubit/player_cubit.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';

import 'fake_player_controller.dart';

void main() {
  group('PlayerCubit', () {
    late FakePlayerController controller;
    late FakePlaybackRepository playback;
    late PlayerCubit cubit;

    setUp(() {
      controller = FakePlayerController();
      playback = FakePlaybackRepository();
      cubit = PlayerCubit(
        controller,
        playback,
        itemKey: 'movie:m1',
        url: 'http://x',
        title: 'Dune',
        kind: MediaKind.movie,
        playlistId: 'p1',
      );
    });

    tearDown(() => cubit.close());

    group('controls auto-hide', () {
      test('controls start visible after start()', () async {
        await cubit.start();
        expect(cubit.state.showControls, isTrue);
      });

      test('revealControls re-shows controls after being hidden', () async {
        await cubit.start();
        cubit.hideControlsForTesting();
        expect(cubit.state.showControls, isFalse);

        cubit.revealControls();
        expect(cubit.state.showControls, isTrue);
      });

      test('pausing keeps controls visible (no auto-hide while paused)',
          () async {
        await cubit.start();
        expect(cubit.state.isPlaying, isTrue);
        cubit.hideControlsForTesting();
        expect(cubit.state.showControls, isFalse);

        await cubit.togglePlayPause(); // pause
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(cubit.state.isPlaying, isFalse);
        expect(cubit.state.showControls, isTrue,
            reason: 'Controls must reappear and stay when paused');
      });
    });

    group('live-aware progress', () {
      test('channel kind: after start()+close(), no progress saved', () async {
        final liveController = FakePlayerController();
        final livePlayback = FakePlaybackRepository();
        final liveCubit = PlayerCubit(
          liveController,
          livePlayback,
          itemKey: 'channel:c1',
          url: 'http://live',
          title: 'NOOR One',
          kind: MediaKind.channel,
          playlistId: 'p1',
        );
        await liveCubit.start();
        await liveCubit.close();

        final saved = await livePlayback.progressFor('channel:c1');
        expect(saved, isNull, reason: 'Live channels must not persist watch progress');
      });

      test('movie kind: after start()+close(), progress IS saved', () async {
        final movieController = FakePlayerController();
        final moviePlayback = FakePlaybackRepository();
        final movieCubit = PlayerCubit(
          movieController,
          moviePlayback,
          itemKey: 'movie:m1',
          url: 'http://vod',
          title: 'Dune',
          kind: MediaKind.movie,
          playlistId: 'p1',
        );
        await movieCubit.start();
        await movieController.seek(const Duration(seconds: 60));
        await movieCubit.close();

        final saved = await moviePlayback.progressFor('movie:m1');
        expect(saved, isNotNull, reason: 'VOD (movie) must persist watch progress on close');
        expect(saved!.positionSec, 60);
      });

      test('movie kind: saveProgressNow() persists mid-playback (no close)',
          () async {
        final controller = FakePlayerController();
        final playback = FakePlaybackRepository();
        final cubit = PlayerCubit(
          controller,
          playback,
          itemKey: 'movie:m2',
          url: 'http://vod',
          title: 'Dune',
          kind: MediaKind.movie,
          playlistId: 'p1',
        );
        await cubit.start();
        await controller.seek(const Duration(seconds: 120));

        // Simulates the periodic timer / app-background checkpoint firing
        // before any clean close().
        await cubit.saveProgressNow();

        final saved = await playback.progressFor('movie:m2');
        expect(saved, isNotNull,
            reason: 'progress must persist mid-playback, not only on close');
        expect(saved!.positionSec, 120);
        await cubit.close();
      });

      test('channel kind: saveProgressNow() persists nothing (live)', () async {
        final controller = FakePlayerController();
        final playback = FakePlaybackRepository();
        final cubit = PlayerCubit(
          controller,
          playback,
          itemKey: 'channel:c2',
          url: 'http://live',
          title: 'NOOR One',
          kind: MediaKind.channel,
          playlistId: 'p1',
        );
        await cubit.start();
        await controller.seek(const Duration(seconds: 120));
        await cubit.saveProgressNow();

        expect(await playback.progressFor('channel:c2'), isNull);
        await cubit.close();
      });

      test('start() records the item in recently-viewed (live included)',
          () async {
        final playback = FakePlaybackRepository();
        final cubit = PlayerCubit(
          FakePlayerController(),
          playback,
          itemKey: 'channel:c1',
          url: 'http://live',
          title: 'NOOR One',
          kind: MediaKind.channel,
          playlistId: 'p1',
        );
        await cubit.start();
        await Future<void>.delayed(Duration.zero);

        final recent = await playback.recentlyViewed('p1').first;
        expect(recent, contains('channel:c1'));

        await cubit.close();
      });

      test('start() records recentKey (series) when playing an episode',
          () async {
        final playback = FakePlaybackRepository();
        final cubit = PlayerCubit(
          FakePlayerController(),
          playback,
          itemKey: 'episode:e9',
          url: 'http://vod',
          title: 'Ep 9',
          kind: MediaKind.episode,
          playlistId: 'p1',
          recentKey: 'series:s1',
        );
        await cubit.start();
        await Future<void>.delayed(Duration.zero);

        final recent = await playback.recentlyViewed('p1').first;
        expect(recent, contains('series:s1'));
        expect(recent, isNot(contains('episode:e9')));

        await cubit.close();
      });

      test('isLive returns true for channel, false for movie', () {
        final liveController = FakePlayerController();
        final liveCubit = PlayerCubit(
          liveController,
          FakePlaybackRepository(),
          itemKey: 'channel:c1',
          url: 'http://live',
          title: 'Live',
          kind: MediaKind.channel,
          playlistId: 'p1',
        );
        expect(liveCubit.isLive, isTrue);
        liveCubit.close();

        expect(cubit.isLive, isFalse);
      });

      test('channel start() does NOT resume from saved progress', () async {
        // Seed a fake progress entry before the live cubit starts
        final liveController = FakePlayerController();
        final livePlayback = FakePlaybackRepository();
        await livePlayback.saveProgress(
          WatchProgress(
            itemKey: 'channel:c1',
            playlistId: 'p1',
            kind: MediaKind.channel,
            positionSec: 300,
            durationSec: 0,
            updatedAt: DateTime.utc(2026),
          ),
        );

        final liveCubit = PlayerCubit(
          liveController,
          livePlayback,
          itemKey: 'channel:c1',
          url: 'http://live',
          title: 'NOOR One',
          kind: MediaKind.channel,
          playlistId: 'p1',
        );
        await liveCubit.start();

        // The controller should NOT have been seeked (position stays at zero)
        expect(liveController.position, Duration.zero,
            reason: 'Live channels must not seek to a resume position');

        await liveCubit.close();
      });
    });

    group('resume & watched handling', () {
      // FakePlayerController reports a 90-minute (5400 s) duration.
      WatchProgress progressAt(int pos) => WatchProgress(
            itemKey: 'movie:m1',
            playlistId: 'p1',
            kind: MediaKind.movie,
            positionSec: pos,
            durationSec: 5400,
            updatedAt: DateTime.utc(2026),
          );

      test('partially watched item resumes at the saved position', () async {
        await playback.saveProgress(progressAt(2400));
        await cubit.start();
        expect(controller.position, const Duration(seconds: 2400));
      });

      test('watched item (>= 95%) restarts from the beginning', () async {
        await playback.saveProgress(progressAt(5300)); // ~98% watched
        await cubit.start();
        expect(controller.position, Duration.zero,
            reason: 'A finished item must replay from the start, not resume '
                'at the last seconds');
      });

      test('closing before playback begins keeps the existing resume point',
          () async {
        // User backs out while the stream is still buffering: the controller
        // position is still zero. That zero must not clobber the real
        // resume point saved by an earlier session.
        await playback.saveProgress(progressAt(2400));

        final earlyExitCubit = PlayerCubit(
          FakePlayerController(),
          playback,
          itemKey: 'movie:m1',
          url: 'http://vod',
          title: 'Dune',
          kind: MediaKind.movie,
          playlistId: 'p1',
        );
        await earlyExitCubit.close(); // never started

        final saved = await playback.progressFor('movie:m1');
        expect(saved!.positionSec, 2400,
            reason: 'a zero-position save must not overwrite real progress');
      });
    });

    test('start() → isPlaying true', () async {
      await cubit.start();
      expect(cubit.state.isPlaying, isTrue);
    });

    test('togglePlayPause() flips isPlaying', () async {
      await cubit.start();
      expect(cubit.state.isPlaying, isTrue);
      await cubit.togglePlayPause();
      expect(cubit.state.isPlaying, isFalse);
      await cubit.togglePlayPause();
      expect(cubit.state.isPlaying, isTrue);
    });

    test('skipForward() advances position by 10s', () async {
      await cubit.start();
      await cubit.skipForward();
      expect(cubit.state.position, const Duration(seconds: 10));
    });

    test('toggleCaptions() flips captionsOn', () async {
      await cubit.start();
      expect(cubit.state.captionsOn, isFalse);
      cubit.toggleCaptions();
      expect(cubit.state.captionsOn, isTrue);
      cubit.toggleCaptions();
      expect(cubit.state.captionsOn, isFalse);
    });

    test('kind and playlistId are stored on the cubit', () {
      expect(cubit.kind, MediaKind.movie);
      expect(cubit.playlistId, 'p1');
    });

    test('setVolume(0.3) sets state.volume to 0.3', () async {
      await cubit.start();
      await cubit.setVolume(0.3);
      expect(cubit.state.volume, closeTo(0.3, 0.001));
    });

    test('setVolume clamps values outside 0..1', () async {
      await cubit.start();
      await cubit.setVolume(1.5);
      expect(cubit.state.volume, 1.0);
      await cubit.setVolume(-0.5);
      expect(cubit.state.volume, 0.0);
    });

    test('toggleMute() sets muted=true and volume 0 on controller', () async {
      await cubit.start();
      await cubit.setVolume(0.7);
      await cubit.toggleMute();
      expect(cubit.state.muted, isTrue);
      expect(controller.volume, closeTo(0.0, 0.001));
    });

    test('toggleMute() twice restores original volume', () async {
      await cubit.start();
      await cubit.setVolume(0.3);
      await cubit.toggleMute();
      expect(cubit.state.muted, isTrue);
      await cubit.toggleMute();
      expect(cubit.state.muted, isFalse);
      expect(cubit.state.volume, closeTo(0.3, 0.001));
      expect(controller.volume, closeTo(0.3, 0.001));
    });

    // ── computeStreamBadge pure-function unit tests ──────────────────────────

    group('computeStreamBadge()', () {
      test('≥ 1 Mbps → "X.X Mbps" with one decimal', () {
        expect(
          PlayerCubit.computeStreamBadge(bitRate: 4200000, resolutionBadge: null),
          '4.2 Mbps',
        );
      });

      test('exactly 1 000 000 bps → "1.0 Mbps"', () {
        expect(
          PlayerCubit.computeStreamBadge(bitRate: 1000000, resolutionBadge: null),
          '1.0 Mbps',
        );
      });

      test('< 1 Mbps → "X Kbps"', () {
        expect(
          PlayerCubit.computeStreamBadge(bitRate: 850000, resolutionBadge: null),
          '850 Kbps',
        );
      });

      test('bitRate == 0 → falls back to resolutionBadge', () {
        expect(
          PlayerCubit.computeStreamBadge(bitRate: 0, resolutionBadge: '1280×720'),
          '1280×720',
        );
      });

      test('bitRate == null → falls back to resolutionBadge', () {
        expect(
          PlayerCubit.computeStreamBadge(bitRate: null, resolutionBadge: '1920×1080'),
          '1920×1080',
        );
      });

      test('bitRate == 0 and resolutionBadge == null → returns null', () {
        expect(
          PlayerCubit.computeStreamBadge(bitRate: 0, resolutionBadge: null),
          isNull,
        );
      });
    });

    // ── Integration: streamBadge in cubit state ───────────────────────────────

    test('start() → streamBadge reflects 4.2 Mbps from fake controller', () async {
      controller.currentBitRate = 4200000;
      await cubit.start();
      expect(cubit.state.streamBadge, '4.2 Mbps');
    });

    test('start() with currentBitRate=0 → badge falls back to null (no resolution in fake)', () async {
      controller.currentBitRate = 0;
      await cubit.start();
      // FakePlayerController.streamBadge returns null → no badge
      expect(cubit.state.streamBadge, isNull);
    });

    test('pollBitrateBadgeForTesting() updates badge on each call', () async {
      // Start with 2 Mbps
      controller.currentBitRate = 2000000;
      await cubit.start();
      expect(cubit.state.streamBadge, '2.0 Mbps');

      // Simulate a timer tick with a different bitrate
      controller.currentBitRate = 500000;
      cubit.pollBitrateBadgeForTesting();
      expect(cubit.state.streamBadge, '500 Kbps');

      // Another tick — back to high bitrate
      controller.currentBitRate = 1500000;
      cubit.pollBitrateBadgeForTesting();
      expect(cubit.state.streamBadge, '1.5 Mbps');

      // bitRate drops to 0 → fallback to resolution (null in fake)
      controller.currentBitRate = 0;
      cubit.pollBitrateBadgeForTesting();
      expect(cubit.state.streamBadge, isNull);
    });

    test('pollBitrateBadgeForTesting() is a no-op after close()', () async {
      controller.currentBitRate = 1000000;
      await cubit.start();
      expect(cubit.state.streamBadge, '1.0 Mbps');

      // Close the cubit
      await cubit.close();

      // Calling the poll after close must not throw even though isClosed==true
      expect(() => cubit.pollBitrateBadgeForTesting(), returnsNormally);
    });
    group('loading and failures', () {
      test('start() clears loading once playback produces motion', () async {
        expect(cubit.state.loading, isTrue, reason: 'spinner before start');
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.loading, isFalse);
        expect(cubit.state.error, isNull);
      });

      test('re-buffering mid-playback shows the spinner again', () async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.loading, isFalse);

        controller.buffering = true;
        controller.emitStatusForTesting();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.loading, isTrue);

        controller.buffering = false;
        controller.emitStatusForTesting();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.loading, isFalse);
      });

      test('a deliberate pause does NOT bring the spinner back', () async {
        await cubit.start();
        await Future<void>.delayed(Duration.zero);
        await cubit.togglePlayPause();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isPlaying, isFalse);
        expect(cubit.state.loading, isFalse);
      });

      test('an empty url fails fast, without asking the backend', () async {
        final empty = PlayerCubit(
          controller,
          playback,
          itemKey: 'movie:m1',
          url: '',
          title: 'Dune',
          kind: MediaKind.movie,
          playlistId: 'p1',
        );
        addTearDown(empty.close);

        await empty.start();
        expect(empty.state.error, PlaybackFailure.unavailable);
        expect(empty.state.loading, isFalse);
        expect(controller.initializeCount, 0);
      });

      test('start() surfaces a failure instead of throwing', () async {
        controller.failNextInitializeWith =
            Exception('SocketException: Failed host lookup');
        await expectLater(cubit.start(), completes);
        expect(cubit.state.error, PlaybackFailure.network);
        expect(cubit.state.loading, isFalse);
      });

      test('retry() clears the error and starts again', () async {
        controller.failNextInitializeWith = Exception('HTTP 404 not found');
        await cubit.start();
        expect(cubit.state.error, PlaybackFailure.unavailable);

        await cubit.retry();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.error, isNull);
        expect(cubit.state.isPlaying, isTrue);
        expect(controller.initializeCount, 2);
      });

      test('retry() without an error is a no-op', () async {
        await cubit.start();
        expect(controller.initializeCount, 1);
        await cubit.retry();
        expect(controller.initializeCount, 1);
      });

      test('classifyStartFailure maps provider responses', () {
        expect(PlayerCubit.classifyStartFailure(Exception('HTTP 403 Forbidden')),
            PlaybackFailure.refused);
        expect(PlayerCubit.classifyStartFailure(Exception('401 Unauthorized')),
            PlaybackFailure.refused);
        expect(PlayerCubit.classifyStartFailure(Exception('404 Not Found')),
            PlaybackFailure.unavailable);
        expect(PlayerCubit.classifyStartFailure(Exception('Connection timed out')),
            PlaybackFailure.timeout);
        expect(PlayerCubit.classifyStartFailure(Exception('SocketException')),
            PlaybackFailure.network);
        expect(PlayerCubit.classifyStartFailure(Exception('weird backend text')),
            PlaybackFailure.unknown);
      });
    });
  });
}
