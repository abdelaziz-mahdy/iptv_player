import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/features/player/cubit/player_cubit.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';

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
        await movieCubit.close();

        final saved = await moviePlayback.progressFor('movie:m1');
        expect(saved, isNotNull, reason: 'VOD (movie) must persist watch progress on close');
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
  });
}
