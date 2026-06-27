import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/home/cubit/home_cubit.dart';

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

  group('HomeCubit — favorites', () {
    test('initial favoriteKeys is empty', () {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );
      expect(cubit.state.favoriteKeys, isEmpty);
    });

    test('favoriteKeys updates when toggleFavoriteMovie is called', () async {
      final contentRepo = FakeContentRepository();
      final cubit = HomeCubit(
        contentRepo,
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, isEmpty);

      final movie = cubit.state.movies.firstWhere((m) => m.title == 'Dune');
      await cubit.toggleFavoriteMovie(movie);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, contains('movie:${movie.id}'));

      await cubit.close();
    });

    test('toggleFavoriteMovie removes movie when already favorited', () async {
      final contentRepo = FakeContentRepository();
      final cubit = HomeCubit(
        contentRepo,
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final movie = cubit.state.movies.firstWhere((m) => m.title == 'Dune');

      await cubit.toggleFavoriteMovie(movie);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.favoriteKeys, contains('movie:${movie.id}'));

      await cubit.toggleFavoriteMovie(movie);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.favoriteKeys, isNot(contains('movie:${movie.id}')));

      await cubit.close();
    });

    test('toggleFavoriteSeries keys series as episode:<id>', () async {
      final contentRepo = FakeContentRepository();
      final cubit = HomeCubit(
        contentRepo,
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final show = cubit.state.series.firstWhere((s) => s.title == 'Horizon');
      await cubit.toggleFavoriteSeries(show);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, contains('episode:${show.id}'));

      await cubit.close();
    });
  });
}
