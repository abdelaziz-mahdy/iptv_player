import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/details/cubit/details_cubit.dart';

Series _series(String id) =>
    Series(id: id, playlistId: 'p1', title: 'Show $id');

void main() {
  group('DetailsCubit', () {
    test('loadSeries populates seasons, episodes and description', () async {
      final cubit = DetailsCubit(FakeContentRepository());

      await cubit.loadSeries(_series('s1'));

      final state = cubit.state;
      expect(state.loading, isFalse);
      expect(state.seasons, isNotEmpty);
      expect(state.episodes.length, 2);
      expect(state.episodes.map((e) => e.title),
          containsAll(['Pilot', 'Contact']));
      expect(state.description, isNotNull);
    });

    test('loadSeries unknown id yields empty seasons and episodes', () async {
      final cubit = DetailsCubit(FakeContentRepository());

      await cubit.loadSeries(_series('unknown'));

      expect(cubit.state.seasons, isEmpty);
      expect(cubit.state.episodes, isEmpty);
      expect(cubit.state.loading, isFalse);
    });

    test('selectSeason switches episodes from the cached map', () async {
      final cubit = DetailsCubit(FakeContentRepository());

      // s2 has one season with 1 episode.
      await cubit.loadSeries(_series('s2'));
      expect(cubit.state.episodes.length, 1);

      // Selecting index 0 again should still return 1 episode (no refetch).
      cubit.selectSeason(0);
      expect(cubit.state.episodes.length, 1);
      expect(cubit.state.selectedSeasonIndex, 0);
    });
  });
}
