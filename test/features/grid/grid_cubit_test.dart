import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/grid/cubit/grid_cubit.dart';

void main() {
  group('GridCubit — category names', () {
    test('movies: category chips contain human names (Action, Drama) not raw ids', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // State should expose CategoryRef list with human names
      final categoryNames = cubit.state.categories.map((c) => c.name).toList();
      expect(categoryNames, containsAll(['Action', 'Drama']),
          reason: 'should expose human names from FakeContentRepository.categories()');
      // Must NOT contain raw ids like 'cat1'
      expect(categoryNames, isNot(contains('cat1')));
      expect(categoryNames, isNot(contains('cat2')));

      await cubit.close();
    });

    test('movies: an "All" CategoryRef is included at index 0', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.categories.isNotEmpty, isTrue);
      expect(cubit.state.categories.first.name, 'All');
      expect(cubit.state.categories.first.id, '');

      await cubit.close();
    });

    test('series: category chips contain Sci-Fi from fake', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.series,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final categoryNames = cubit.state.categories.map((c) => c.name).toList();
      expect(categoryNames, contains('Sci-Fi'));
      // Must NOT expose raw ids like 'cat5'
      expect(categoryNames, isNot(contains('cat5')));

      await cubit.close();
    });

    test('selecting All category (id empty string) clears filter', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // Select a real category chip
      final actionCat = cubit.state.categories
          .firstWhere((c) => c.name == 'Action');
      cubit.selectCategory(actionCat.id);
      expect(cubit.state.selectedCategoryId, equals(actionCat.id));

      // Select "All" chip (id == '')
      cubit.selectCategory('');
      expect(cubit.state.selectedCategoryId, isNull,
          reason: 'Selecting All chip should clear the filter');

      await cubit.close();
    });
  });

  group('GridCubit — movies', () {
    test('load() emits non-empty items for movies kind', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.items, isNotEmpty);
      expect(cubit.state.loading, isFalse);

      await cubit.close();
    });

    test('items contain expected fake movie titles', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final titles = cubit.state.items.map((e) => e.title).toList();
      expect(titles, containsAll(['The Signal', 'Dune', 'Arrival', 'Interstellar']));

      await cubit.close();
    });

    test('selectCategory filters items', () async {
      final contentRepo = FakeContentRepository();
      final cubit = GridCubit(
        contentRepo,
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // Default: no filter, all items visible
      final allCount = cubit.state.items.length;
      expect(allCount, greaterThan(0));

      // Select a category that no item has — filtered list should be empty
      cubit.selectCategory('NonExistentCat');
      final filtered = cubit.state.items
          .where((e) => e.badge == 'NonExistentCat')
          .toList();
      expect(filtered, isEmpty);

      // Clear filter with null
      cubit.selectCategory(null);
      expect(cubit.state.selectedCategoryId, isNull);

      await cubit.close();
    });

    test('initial state has loading=false and empty items', () {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.items, isEmpty);
    });

    test('GridState copyWith preserves unset fields', () {
      const state = GridState();
      final updated = state.copyWith(loading: true);
      expect(updated.loading, isTrue);
      expect(updated.items, isEmpty);
      expect(updated.selectedCategoryId, isNull);
    });
  });

  group('GridCubit — series', () {
    test('load() emits non-empty items for series kind', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.series,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.items, isNotEmpty);
      final titles = cubit.state.items.map((e) => e.title).toList();
      expect(titles, containsAll(['Deep Field', 'Horizon']));

      await cubit.close();
    });
  });
}
