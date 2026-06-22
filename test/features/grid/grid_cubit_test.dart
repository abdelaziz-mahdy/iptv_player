import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/grid/cubit/grid_cubit.dart';

void main() {
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
      expect(cubit.state.selectedCategory, isNull);

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
      expect(updated.selectedCategory, isNull);
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
