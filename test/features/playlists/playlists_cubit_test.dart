import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/playlists/cubit/playlists_cubit.dart';

void main() {
  group('PlaylistsCubit', () {
    late FakePlaylistRepository playlists;
    late PlaylistsCubit cubit;

    setUp(() {
      playlists = FakePlaylistRepository();
      cubit = PlaylistsCubit(playlists);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial state is loading=false with empty playlists', () {
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.playlists, isEmpty);
      expect(cubit.state.activeId, isNull);
    });

    test('load() yields seeded p1 playlist in state.playlists', () async {
      await cubit.load();

      expect(cubit.state.playlists, isNotEmpty);
      expect(cubit.state.playlists.any((p) => p.id == 'p1'), isTrue);
    });

    test('select(p1) sets state.activeId == p1', () async {
      await cubit.load();
      await cubit.select('p1');

      expect(cubit.state.activeId, 'p1');
    });
  });
}
