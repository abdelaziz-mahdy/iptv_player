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

    test('FavoritesState copyWith preserves unset fields', () {
      const state = FavoritesState();
      final updated = state.copyWith(loading: true);
      expect(updated.loading, isTrue);
      expect(updated.entries, isEmpty);
    });
  });
}
