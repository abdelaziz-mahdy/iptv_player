import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/search/cubit/search_cubit.dart';

void main() {
  group('SearchCubit', () {
    test('initial state has empty query, empty results, loading=false', () {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      expect(cubit.state.query, isEmpty);
      expect(cubit.state.results, isEmpty);
      expect(cubit.state.loading, isFalse);
    });

    test('load() caches content and clears loading flag', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();

      expect(cubit.state.loading, isFalse);
    });

    test('setQuery("dune") returns results containing Dune', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      await cubit.load();

      cubit.setQuery('dune');

      expect(cubit.state.query, 'dune');
      expect(
        cubit.state.results.any(
          (e) => e.title.toLowerCase().contains('dune'),
        ),
        isTrue,
      );
    });

    test('setQuery("") produces empty results', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      await cubit.load();

      cubit.setQuery('dune');
      cubit.setQuery('');

      expect(cubit.state.query, isEmpty);
      expect(cubit.state.results, isEmpty);
    });

    test('setQuery is case-insensitive', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      await cubit.load();

      cubit.setQuery('DUNE');

      expect(
        cubit.state.results.any(
          (e) => e.title == 'Dune',
        ),
        isTrue,
      );
    });

    test('setQuery("horizon") returns series result', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      await cubit.load();

      cubit.setQuery('horizon');

      expect(
        cubit.state.results.any(
          (e) => e.title == 'Horizon' && e.kind == SearchEntryKind.series,
        ),
        isTrue,
      );
    });

    test('SearchState copyWith updates fields independently', () {
      const state = SearchState();
      final updated = state.copyWith(query: 'test', loading: true);

      expect(updated.query, 'test');
      expect(updated.loading, isTrue);
      expect(updated.results, isEmpty);
    });

    test('SearchState equality works via Equatable', () {
      const s1 = SearchState();
      const s2 = SearchState();
      expect(s1, equals(s2));
    });

    test('setQuery("dune") yields a movie-kind entry', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      await cubit.load();

      cubit.setQuery('dune');

      expect(
        cubit.state.results.any(
          (e) =>
              e.title.toLowerCase().contains('dune') &&
              e.kind == SearchEntryKind.movie,
        ),
        isTrue,
      );
    });

    test('byKind splits results into movies vs series', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      await cubit.load();

      // Search for something that returns both movies and series if available,
      // or verify the split works independently.
      cubit.setQuery('dune');
      final results = cubit.state.results;

      final movies = SearchCubit.byKind(results, SearchEntryKind.movie);
      final series = SearchCubit.byKind(results, SearchEntryKind.series);

      // Dune is a movie — must appear in movies group.
      expect(movies.any((e) => e.title == 'Dune'), isTrue);
      // No series matches 'dune' in the fake data.
      expect(series, isEmpty);

      // Verify every entry in movies is actually a movie kind.
      expect(movies.every((e) => e.kind == SearchEntryKind.movie), isTrue);
    });

    test('channels are excluded from search results', () async {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      await cubit.load();

      // Search for 'noor' — matches channel names but channels should be
      // excluded from VOD search.
      cubit.setQuery('noor');

      expect(
        cubit.state.results.any((e) => e.kind == SearchEntryKind.channel),
        isFalse,
      );
    });
  });

  group('SearchCubit — favorites', () {
    test('initial favoriteKeys is empty', () {
      final cubit = SearchCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );
      expect(cubit.state.favoriteKeys, isEmpty);
    });

    test('favoriteKeys updates when toggleFavorite is called on a movie entry', () async {
      final contentRepo = FakeContentRepository();
      final cubit = SearchCubit(contentRepo, FakePlaylistRepository());

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      cubit.setQuery('dune');
      final duneEntry = cubit.state.results.firstWhere((e) => e.title == 'Dune');

      await cubit.toggleFavorite(duneEntry);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, contains('movie:${duneEntry.id}'));

      await cubit.close();
    });

    test('toggleFavorite keys series entry as episode:<id>', () async {
      final contentRepo = FakeContentRepository();
      final cubit = SearchCubit(contentRepo, FakePlaylistRepository());

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      cubit.setQuery('horizon');
      final horizonEntry = cubit.state.results.firstWhere(
        (e) => e.title == 'Horizon' && e.kind == SearchEntryKind.series,
      );

      await cubit.toggleFavorite(horizonEntry);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, contains('episode:${horizonEntry.id}'));

      await cubit.close();
    });

    test('favoriteKeys reflects repository favorites stream', () async {
      final contentRepo = FakeContentRepository();
      final cubit = SearchCubit(contentRepo, FakePlaylistRepository());

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, isEmpty);

      // Externally toggle via repo
      await contentRepo.toggleFavorite('movie:m2', 'p1', MediaKind.movie);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, contains('movie:m2'));

      await cubit.close();
    });
  });
}
