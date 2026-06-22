import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/live/cubit/live_cubit.dart';

void main() {
  group('LiveCubit', () {
    test('initial state has loading=false with empty collections', () {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakeEpgRepository(),
        FakePlaylistRepository(),
      );

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.channels, isEmpty);
      expect(cubit.state.epgByChannel, isEmpty);
    });

    test('load() emits state with non-empty channels', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakeEpgRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      // Give stream a chance to emit
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.channels, isNotEmpty);

      await cubit.close();
    });

    test('load() emits epgByChannel with entries for each channel', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakeEpgRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.epgByChannel, isNotEmpty);

      // Every channel should have at least one entry in the EPG map.
      for (final ch in cubit.state.channels) {
        expect(
          cubit.state.epgByChannel.containsKey(ch.id),
          isTrue,
          reason: 'EPG missing for channel ${ch.id}',
        );
        expect(
          cubit.state.epgByChannel[ch.id],
          isNotEmpty,
          reason: 'EPG empty for channel ${ch.id}',
        );
      }

      await cubit.close();
    });

    test('load() sets loading=false after channels arrive', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakeEpgRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.loading, isFalse);

      await cubit.close();
    });

    test('LiveState copyWith returns updated fields', () {
      const initial = LiveState();
      final updated = initial.copyWith(loading: true);

      expect(updated.loading, isTrue);
      expect(updated.channels, isEmpty);
    });

    test('LiveState props equality works correctly', () {
      const s1 = LiveState();
      const s2 = LiveState();
      expect(s1, equals(s2));
    });
  });
}
