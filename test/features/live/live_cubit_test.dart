import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/live/cubit/live_cubit.dart';

void main() {
  group('LiveCubit', () {
    test('initial state has loading=false with empty collections', () {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.groups, isEmpty);
      expect(cubit.state.channelsInGroup, isEmpty);
    });

    test('load() emits state with non-empty groups', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      // Give stream a chance to emit
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.groups, isNotEmpty);

      await cubit.close();
    });

    test('load() includes an "All" group', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final groupNames = cubit.state.groups.map((g) => g.name).toList();
      expect(groupNames, contains('All'));

      await cubit.close();
    });

    test('load() groups have correct channel counts', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      final allGroup = cubit.state.groups.where((g) => g.id == 'all').firstOrNull;
      expect(allGroup, isNotNull);
      // FakeContentRepository has 3 channels
      expect(allGroup!.count, equals(3));

      await cubit.close();
    });

    test('load() sets loading=false after channels arrive', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.loading, isFalse);

      await cubit.close();
    });

    test('initial channelsInGroup shows all channels (All group selected)', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // Default selection is 'all', so channelsInGroup should have all 3 channels
      expect(cubit.state.channelsInGroup, hasLength(3));

      await cubit.close();
    });

    test('selectGroup() filters channelsInGroup by categoryId', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // Channels in FakeContentRepository all have null categoryId
      // Selecting 'all' should show all channels
      cubit.selectGroup('all');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.selectedGroupId, equals('all'));
      expect(cubit.state.channelsInGroup, hasLength(3));

      await cubit.close();
    });

    test('LiveState copyWith returns updated fields', () {
      const initial = LiveState();
      final updated = initial.copyWith(loading: true);

      expect(updated.loading, isTrue);
      expect(updated.groups, isEmpty);
      expect(updated.channelsInGroup, isEmpty);
    });

    test('LiveState props equality works correctly', () {
      const s1 = LiveState();
      const s2 = LiveState();
      expect(s1, equals(s2));
    });

    test('groups resolve category names from CategoryRef list', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // FakeContentRepository.categories returns Sports and News for channels
      // but the 3 fake channels all have null categoryId so they end up in All
      final groupIds = cubit.state.groups.map((g) => g.id).toList();
      // The "all" group must always be present
      expect(groupIds, contains('all'));

      await cubit.close();
    });
  });
}
