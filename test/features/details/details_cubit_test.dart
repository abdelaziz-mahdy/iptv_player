import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/details/cubit/details_cubit.dart';

void main() {
  group('DetailsCubit', () {
    test('loadSeries("s1") populates seasons and episodes', () async {
      final cubit = DetailsCubit(FakeContentRepository());

      await cubit.loadSeries('s1');

      final state = cubit.state;
      expect(state.loading, isFalse);
      expect(state.seasons, isNotEmpty);
      expect(state.episodes.length, 2);
      expect(state.episodes.map((e) => e.title),
          containsAll(['Pilot', 'Contact']));
    });

    test('loadSeries unknown id yields empty seasons and episodes', () async {
      final cubit = DetailsCubit(FakeContentRepository());

      await cubit.loadSeries('unknown');

      expect(cubit.state.seasons, isEmpty);
      expect(cubit.state.episodes, isEmpty);
      expect(cubit.state.loading, isFalse);
    });

    test('selectSeason switches episodes', () async {
      final cubit = DetailsCubit(FakeContentRepository());

      // Load s2 which has one season with 1 episode
      await cubit.loadSeries('s2');
      expect(cubit.state.episodes.length, 1);

      // Selecting index 0 again should still return 1 episode
      await cubit.selectSeason(0);
      expect(cubit.state.episodes.length, 1);
    });
  });
}
