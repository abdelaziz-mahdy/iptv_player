import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/favorites/cubit/favorites_cubit.dart';

void main() {
  group('FavoritesCubit', () {
    test('isEmpty is true before any favorites are added', () async {
      final cubit = FavoritesCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isEmpty, isTrue);
      expect(cubit.state.entries, isEmpty);

      await cubit.close();
    });

    test('initial state has loading=false and no entries', () {
      final cubit = FavoritesCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.entries, isEmpty);
    });

    test('one entry resolves after toggleFavorite for movie:m1', () async {
      final contentRepo = FakeContentRepository();

      // Add the favorite before loading the cubit so the stream already has it
      await contentRepo.toggleFavorite('movie:m1', 'p1', MediaKind.movie);

      final cubit = FavoritesCubit(
        contentRepo,
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.entries.first.title, equals('The Signal'));
      expect(cubit.state.isEmpty, isFalse);
      // The stream URL has to travel with the entry: the detail screen builds
      // its VodItem from it, and an empty one reaches the player as
      // "invalid or unsupported media".
      expect(cubit.state.entries.first.streamUrl, equals('http://x/m1'));

      await cubit.close();
    });

    test('series favorited as episode:<seriesId> resolves and shows', () async {
      final contentRepo = FakeContentRepository();

      // Series are favorited app-wide as `episode:<seriesId>` (grid/search/
      // details). The favorites list must still resolve them as the series.
      await contentRepo.toggleFavorite('episode:s1', 'p1', MediaKind.episode);

      final cubit = FavoritesCubit(
        contentRepo,
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.entries.first.title, equals('Deep Field'));
      expect(cubit.state.entries.first.isSeries, isTrue);

      await cubit.close();
    });

    test('toggleFavorite twice removes the entry (toggle off)', () async {
      final contentRepo = FakeContentRepository();
      await contentRepo.toggleFavorite('movie:m1', 'p1', MediaKind.movie);
      await contentRepo.toggleFavorite('movie:m1', 'p1', MediaKind.movie);

      final cubit = FavoritesCubit(
        contentRepo,
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.isEmpty, isTrue);

      await cubit.close();
    });

    // Provider stream ids embedded in favorite keys are not stable across
    // re-imports — these cover the self-healing resolution (title snapshot).
    group('id renumbering', () {
      test('stale id heals by title: favorite follows the renamed id', () async {
        final contentRepo = FakeContentRepository();
        // 'm9' does not exist in the catalog — simulates the provider having
        // renumbered The Signal from m9 to m1 since the favorite was added.
        await contentRepo.toggleFavorite('movie:m9', 'p1', MediaKind.movie,
            title: 'The Signal');

        final cubit = FavoritesCubit(contentRepo, FakePlaylistRepository());
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.entries, hasLength(1));
        expect(cubit.state.entries.first.title, 'The Signal');
        expect(cubit.state.entries.first.id, 'm1');

        // The favorite row was rewritten to the current id.
        await Future<void>.delayed(Duration.zero);
        final favs = await contentRepo.favorites('p1').first;
        expect(favs.single.itemKey, 'movie:m1');
        expect(favs.single.title, 'The Signal');

        await cubit.close();
      });

      test('reused id resolves by title, not by the reassigned id', () async {
        final contentRepo = FakeContentRepository();
        // The favorite's key says m1, but its stored title is Dune (m2):
        // the provider reused id m1 for different content after re-import.
        await contentRepo.toggleFavorite('movie:m1', 'p1', MediaKind.movie,
            title: 'Dune');

        final cubit = FavoritesCubit(contentRepo, FakePlaylistRepository());
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.entries, hasLength(1));
        expect(cubit.state.entries.first.title, 'Dune');
        expect(cubit.state.entries.first.id, 'm2');

        await Future<void>.delayed(Duration.zero);
        final favs = await contentRepo.favorites('p1').first;
        expect(favs.single.itemKey, 'movie:m2');

        await cubit.close();
      });

      test('rename with stable id keeps the item and adopts the new title',
          () async {
        final contentRepo = FakeContentRepository();
        // id m1 exists but the provider renamed it since the favorite was
        // added; no catalog item carries the old title.
        await contentRepo.toggleFavorite('movie:m1', 'p1', MediaKind.movie,
            title: 'The Signal (Old Cut)');

        final cubit = FavoritesCubit(contentRepo, FakePlaylistRepository());
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.entries, hasLength(1));
        expect(cubit.state.entries.first.id, 'm1');
        expect(cubit.state.entries.first.title, 'The Signal');

        await Future<void>.delayed(Duration.zero);
        final favs = await contentRepo.favorites('p1').first;
        expect(favs.single.itemKey, 'movie:m1');
        expect(favs.single.title, 'The Signal');

        await cubit.close();
      });

      test('legacy favorite without title resolves by id and backfills',
          () async {
        final contentRepo = FakeContentRepository();
        await contentRepo.toggleFavorite('movie:m1', 'p1', MediaKind.movie);

        final cubit = FavoritesCubit(contentRepo, FakePlaylistRepository());
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.entries, hasLength(1));
        expect(cubit.state.entries.first.title, 'The Signal');

        await Future<void>.delayed(Duration.zero);
        final favs = await contentRepo.favorites('p1').first;
        expect(favs.single.title, 'The Signal');

        await cubit.close();
      });

      test('favorite for removed content is hidden, not deleted', () async {
        final contentRepo = FakeContentRepository();
        await contentRepo.toggleFavorite('movie:m9', 'p1', MediaKind.movie,
            title: 'Gone Forever');

        final cubit = FavoritesCubit(contentRepo, FakePlaylistRepository());
        await cubit.load();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.entries, isEmpty);

        // Row kept: if the provider brings the item back it resolves again.
        final favs = await contentRepo.favorites('p1').first;
        expect(favs.single.itemKey, 'movie:m9');

        await cubit.close();
      });
    });

    test('FavoritesState copyWith preserves unset fields', () {
      const state = FavoritesState();
      final updated = state.copyWith(loading: true);
      expect(updated.loading, isTrue);
      expect(updated.entries, isEmpty);
    });
  });
}
