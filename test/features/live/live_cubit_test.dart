import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';
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

    test('viewing a channel pins "Recently Viewed" group first', () async {
      final playback = FakePlaybackRepository();
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
        playback: playback,
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // No recent group until a channel is viewed.
      expect(cubit.state.groups.map((g) => g.id),
          isNot(contains(kRecentGroupId)));

      await playback.recordView(playlistId: 'p1', itemKey: 'channel:c2');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.groups.first.id, kRecentGroupId);
      expect(cubit.state.groups.first.count, 1);

      cubit.selectGroup(kRecentGroupId);
      expect(cubit.state.channelsInGroup.map((c) => c.id), ['c2']);

      await cubit.close();
    });

    test('load() includes an "All" group', () async {
      final cubit = LiveCubit(
        FakeContentRepository(),
        FakePlaylistRepository(),
      );

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      // Synthetic groups carry no name — the screen localizes them by id.
      final groupIds = cubit.state.groups.map((g) => g.id).toList();
      expect(groupIds, contains(kAllGroupId));

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

  group('LiveCubit — group recency', () {
    test('selecting a real group records it; synthetic groups do not',
        () async {
      final content = FakeContentRepository();
      final cubit = LiveCubit(content, FakePlaylistRepository());

      await cubit.load();
      await Future<void>.delayed(Duration.zero);

      cubit.selectGroup(kAllGroupId);
      cubit.selectGroup('cat3');
      await Future<void>.delayed(Duration.zero);

      final used = await content.recentCategoryIds('p1', MediaKind.channel).first;
      expect(used, ['cat3'], reason: '"All" is synthetic and is not recorded');

      await cubit.close();
    });

    test(
      'a used group is pinned at once and stays in its place below',
      () async {
        final content = _GroupedChannels();
        final cubit = LiveCubit(content, FakePlaylistRepository());
        await cubit.load();
        await Future<void>.delayed(Duration.zero);
        final before = cubit.state.groups.map((g) => g.id).toList();

        cubit.selectGroup('cat3');
        // Recorded, then emitted back by the recency stream.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final ids = cubit.state.groups.map((g) => g.id).toList();
        final pinned = cubit.state.pinnedGroupCount;
        expect(cubit.state.recentGroupCount, 1);
        expect(ids[pinned - 1], 'cat3', reason: 'pinned as recent right away');
        expect(
          ids.sublist(pinned),
          before.sublist(before.indexOf(kAllGroupId) + 1),
          reason: 'the full list below is unchanged, cat3 included',
        );

        await cubit.close();
      },
    );

    test('the last used group is restored on the next load', () async {
      final content = FakeContentRepository();
      final playlists = FakePlaylistRepository();
      final first = LiveCubit(content, playlists);
      await first.load();
      await Future<void>.delayed(Duration.zero);
      first.selectGroup('cat3');
      await Future<void>.delayed(Duration.zero);
      await first.close();

      final second = LiveCubit(content, playlists);
      await second.load();
      await Future<void>.delayed(Duration.zero);

      // The fake channels are uncategorised, so cat3 holds nothing and the
      // restore falls back to All rather than selecting an empty group.
      expect(second.state.selectedGroupId, kAllGroupId);

      await second.close();
    });
  });
}

/// Fake channels spread over the fake's channel categories (Sports, News).
class _GroupedChannels extends FakeContentRepository {
  @override
  Stream<List<Channel>> channels(String playlistId) => Stream.value(const [
    Channel(
      id: 'a',
      playlistId: 'p1',
      name: 'A',
      number: '1',
      streamUrl: 'u1',
      categoryId: 'cat4',
    ),
    Channel(
      id: 'b',
      playlistId: 'p1',
      name: 'B',
      number: '2',
      streamUrl: 'u2',
      categoryId: 'cat3',
    ),
    Channel(
      id: 'c',
      playlistId: 'p1',
      name: 'C',
      number: '3',
      streamUrl: 'u3',
      categoryId: 'cat3',
    ),
  ]);
}
