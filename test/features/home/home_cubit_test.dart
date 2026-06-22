import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/home/cubit/home_cubit.dart';

void main() {
  group('HomeCubit', () {
    test('load() emits state with non-empty movies and series', () async {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();

      // Give streams a chance to emit
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.movies, isNotEmpty);
      expect(cubit.state.series, isNotEmpty);
      expect(cubit.state.loading, isFalse);

      await cubit.close();
    });

    test('load() emits state with non-empty channels', () async {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.channels, isNotEmpty);

      await cubit.close();
    });

    test('initial state is loading=false with empty lists', () {
      final cubit = HomeCubit(
        FakeContentRepository(),
        FakePlaybackRepository(),
        FakePlaylistRepository(),
      );

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.movies, isEmpty);
      expect(cubit.state.series, isEmpty);
      expect(cubit.state.channels, isEmpty);
      expect(cubit.state.continueWatching, isEmpty);
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
  });
}
