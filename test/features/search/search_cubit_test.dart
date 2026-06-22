import 'package:flutter_test/flutter_test.dart';
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
  });
}
