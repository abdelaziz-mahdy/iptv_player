import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/home/cubit/home_cubit.dart';

void main() {
  group('HomeCubit', () {
    test('load() emits state with non-empty movies and series', () async {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.movies, isNotEmpty);
      expect(cubit.state.series, isNotEmpty);
      expect(cubit.state.loading, isFalse);

      await cubit.close();
    });

    test('initial state has no channels field', () {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.movies, isEmpty);
      expect(cubit.state.series, isEmpty);
      expect(cubit.state.continueWatching, isEmpty);
      // HomeState no longer has a channels field.
    });

    test('HomeState copyWith returns updated fields', () {
      const initial = HomeState();
      final updated = initial.copyWith(loading: true);

      expect(updated.loading, isTrue);
      expect(updated.movies, isEmpty);
    });

    test('HomeState props equality works correctly', () {
      const s1 = HomeState();
      const s2 = HomeState();
      expect(s1, equals(s2));
    });

    test('removeFromContinueWatching removes item from state', () async {
      final playback = FakePlaybackRepository();
      final cubit = HomeCubit(
        FakeContentRepository(),
        playback,
        FakePlaylistRepository(),
      );

      await cubit.load();

      // Seed a movie progress entry via the repository directly.
      await playback.saveProgress(WatchProgress(
        itemKey: 'movie:m1',
        playlistId: 'p1',
        kind: MediaKind.movie,
        positionSec: 42,
        durationSec: 120,
        updatedAt: DateTime.utc(2026),
      ));

      // Give the stream a tick to propagate.
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.continueWatching, isNotEmpty);

      await cubit.removeFromContinueWatching('movie:m1');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.continueWatching, isEmpty);

      await cubit.close();
    });
  });
}
