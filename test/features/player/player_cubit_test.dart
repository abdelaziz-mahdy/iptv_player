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
