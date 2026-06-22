import 'package:flutter_test/flutter_test.dart';
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
  });
}
