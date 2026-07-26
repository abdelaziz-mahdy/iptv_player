import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/grid/cubit/grid_cubit.dart';

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
      // The "All" entry is identified by its empty id; the screen localizes it.
      expect(cubit.state.categories.first.id, '');
      expect(cubit.state.categories.first.name, '');

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

  group('GridCubit — recently viewed + counts', () {
    test('no "Recently Viewed" category until something is viewed', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
        playback: FakePlaybackRepository(),
      );
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.categories.map((c) => c.id),
          isNot(contains(kRecentCategoryId)));

      await cubit.close();
    });

    test('viewing a movie pins "Recently Viewed" first and filters to it',
        () async {
      final playback = FakePlaybackRepository();
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
        playback: playback,
      );
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final dune = cubit.state.items.firstWhere((e) => e.title == 'Dune');
      await playback.recordView(playlistId: 'p1', itemKey: 'movie:${dune.id}');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.categories.first.id, kRecentCategoryId);
      expect(cubit.state.categories.first.count, 1);

      cubit.selectCategory(kRecentCategoryId);
      expect(cubit.state.filteredItems.map((e) => e.title), ['Dune']);

      await cubit.close();
    });

    test('"All" category count equals total item count', () async {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );
      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final all = cubit.state.categories.firstWhere((c) => c.id == '');
      expect(all.count, cubit.state.items.length);

      await cubit.close();
    });
  });

  group('GridCubit — favorites', () {
    test('initial favoriteKeys is empty', () {
      final cubit = GridCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        GridKind.movies,
      );
      expect(cubit.state.favoriteKeys, isEmpty);
    });

    test('favoriteKeys reflects favorites stream after load', () async {
      final contentRepo = FakeContentRepository();
      final cubit = GridCubit(
        contentRepo,
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // No favorites yet
      expect(cubit.state.favoriteKeys, isEmpty);

      // Add a favorite externally via the repo
      await contentRepo.toggleFavorite('movie:m1', 'p1', MediaKind.movie);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, contains('movie:m1'));

      await cubit.close();
    });

    test('toggleFavorite(entry) adds movie to favoriteKeys', () async {
      final contentRepo = FakeContentRepository();
      final cubit = GridCubit(
        contentRepo,
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, isEmpty);

      // Use a GridEntry matching a movie
      final entry = cubit.state.items.firstWhere((e) => e.title == 'Dune');
      await cubit.toggleFavorite(entry);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.favoriteKeys, contains('movie:${entry.id}'));

      await cubit.close();
    });

    test('toggleFavorite(entry) removes movie when already favorited', () async {
      final contentRepo = FakeContentRepository();
      final cubit = GridCubit(
        contentRepo,
        FakePlaylistRepository(),
        GridKind.movies,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final entry = cubit.state.items.firstWhere((e) => e.title == 'Dune');

      // Add it
      await cubit.toggleFavorite(entry);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.favoriteKeys, contains('movie:${entry.id}'));

      // Remove it
      await cubit.toggleFavorite(entry);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.favoriteKeys, isNot(contains('movie:${entry.id}')));

      await cubit.close();
    });

    test('toggleFavorite(entry) uses episode kind for series entries', () async {
      final contentRepo = FakeContentRepository();
      final cubit = GridCubit(
        contentRepo,
        FakePlaylistRepository(),
        GridKind.series,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final entry = cubit.state.items.firstWhere((e) => e.title == 'Deep Field');
      await cubit.toggleFavorite(entry);
      await Future<void>.delayed(Duration.zero);

      // Series items are keyed as 'episode:<id>' matching details_screen convention
      expect(cubit.state.favoriteKeys, contains('episode:${entry.id}'));

      await cubit.close();
    });
  });

  group('GridCubit — recent categories', () {
    test('a used category is pinned under All and not repeated below',
        () async {
      final content = FakeContentRepository();
      final cubit = GridCubit(content, FakePlaylistRepository(), GridKind.movies);

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // cat2 (Drama) sits after cat1 (Action) in the provider's order.
      cubit.selectCategory('cat2');
      await Future<void>.delayed(Duration.zero);

      final ids = cubit.state.categories.map((c) => c.id).toList();
      expect(ids, ['', 'cat2', 'cat1'],
          reason: 'used category moves up; it must not appear twice');
      expect(cubit.state.pinnedCategoryCount, 2,
          reason: 'All + one pinned category');

      await cubit.close();
    });

    test('the last used category is restored on the next load', () async {
      final content = FakeContentRepository();
      final playlists = FakePlaylistRepository();
      final first = GridCubit(content, playlists, GridKind.movies);
      await first.load();
      await Future<void>.delayed(Duration.zero);
      first.selectCategory('cat2');
      await Future<void>.delayed(Duration.zero);
      await first.close();

      final second = GridCubit(content, playlists, GridKind.movies);
      await second.load();
      await Future<void>.delayed(Duration.zero);

      expect(second.state.selectedCategoryId, 'cat2');

      await second.close();
    });
  });
}
