import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/details/cubit/details_cubit.dart';

Series _series(String id) =>
    Series(id: id, playlistId: 'p1', title: 'Show $id');

WatchProgress _progress(String episodeId, int pos,
        {int dur = 2700, DateTime? at}) =>
    WatchProgress(
      itemKey: 'episode:$episodeId',
      playlistId: 'p1',
      kind: MediaKind.episode,
      positionSec: pos,
      durationSec: dur,
      updatedAt: at ?? DateTime.utc(2026, 1, 1),
    );

void main() {
  group('DetailsCubit', () {
    late FakePlaybackRepository playback;

    setUp(() {
      playback = FakePlaybackRepository();
    });

    DetailsCubit makeCubit() =>
        DetailsCubit(FakeContentRepository(), playback);

    test('loadSeries populates seasons, episodes and description', () async {
      final cubit = makeCubit();

      await cubit.loadSeries(_series('s1'));

      final state = cubit.state;
      expect(state.loading, isFalse);
      expect(state.seasons, isNotEmpty);
      expect(state.episodes.length, 2);
      expect(state.episodes.map((e) => e.title),
          containsAll(['Pilot', 'Contact']));
      expect(state.info.description, isNotNull);
    });

    test('loadSeries unknown id yields empty seasons and episodes', () async {
      final cubit = makeCubit();

      await cubit.loadSeries(_series('unknown'));

      expect(cubit.state.seasons, isEmpty);
      expect(cubit.state.episodes, isEmpty);
      expect(cubit.state.loading, isFalse);
    });

    test('selectSeason switches episodes from the cached map', () async {
      final cubit = makeCubit();

      // s2 has one season with 1 episode.
      await cubit.loadSeries(_series('s2'));
      expect(cubit.state.episodes.length, 1);

      // Selecting index 0 again should still return 1 episode (no refetch).
      cubit.selectSeason(0);
      expect(cubit.state.episodes.length, 1);
      expect(cubit.state.selectedSeasonIndex, 0);
    });

    test('progressByKey exposes saved episode progress', () async {
      await playback.saveProgress(_progress('s1-1-e1', 600));

      final cubit = makeCubit();
      await cubit.loadSeries(_series('s1'));
      await Future<void>.delayed(Duration.zero); // let stream binding fire

      expect(cubit.state.progressByKey['episode:s1-1-e1']?.positionSec, 600);
    });

    test('progressByKey updates live when progress changes', () async {
      final cubit = makeCubit();
      await cubit.loadSeries(_series('s1'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.progressByKey, isEmpty);

      // Simulates returning from the player after finishing an episode.
      await playback.saveProgress(
          _progress('s1-1-e2', 2650, at: DateTime.utc(2026, 1, 2)));
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.progressByKey.keys, contains('episode:s1-1-e2'));
      expect(
          cubit.state.progressByKey['episode:s1-1-e2']!.isWatched, isTrue);
    });

    group('series-wide episode queue', () {
      test('allEpisodes concatenates the seasons in order', () async {
        final cubit = makeCubit();
        await cubit.loadSeries(_series('s3'));

        expect(cubit.allEpisodes.map((e) => e.title),
            ['S1E1', 'S1E2', 'S2E1', 'S2E2']);
        expect(cubit.indexInSeries(cubit.allEpisodes[2]), 2);
      });

      test('playTarget indexes into the whole series, not the season',
          () async {
        // Season 1 finished → next up is the first episode of season 2, which
        // is index 2 of the series-wide list.
        await playback.saveProgress(_progress('s3-1-e1', 2700));
        await playback.saveProgress(_progress('s3-1-e2', 2700));

        final cubit = makeCubit();
        await cubit.loadSeries(_series('s3'));
        await Future<void>.delayed(Duration.zero);

        final target = cubit.playTarget();
        expect(target, isNotNull);
        expect(target!.episodes.length, 4, reason: 'queue spans both seasons');
        expect(target.episodeIndex, 2);
        expect(target.episodes[target.episodeIndex].title, 'S2E1');
      });
    });
    group('movie metadata', () {
      test('loadMovie fills in the provider metadata', () async {
        final cubit = makeCubit();
        await cubit.loadMovie(const VodItem(
          id: 'p1:vod:42',
          playlistId: 'p1',
          title: 'Dune',
          streamUrl: 'http://x/42',
        ));

        final info = cubit.state.info;
        expect(cubit.state.loading, isFalse);
        expect(info.description, contains('Dune'));
        expect(info.cast, isNotEmpty);
        expect(info.director, 'Grace Hopper');
        expect(info.durationSec, 5400);
        expect(info.hasCredits, isTrue);
        expect(info.isEmpty, isFalse);
      });
    });

    group('MediaDetail', () {
      test('empty detail reports itself empty', () {
        expect(MediaDetail.empty.isEmpty, isTrue);
        expect(MediaDetail.empty.hasCredits, isFalse);
        expect(MediaDetail.empty.trailerUrl, isNull);
      });

      test('a bare youtube id becomes a watch URL, a link is kept', () {
        expect(const MediaDetail(youtubeTrailer: 'abc123').trailerUrl,
            'https://www.youtube.com/watch?v=abc123');
        expect(
          const MediaDetail(youtubeTrailer: 'https://youtu.be/abc123')
              .trailerUrl,
          'https://youtu.be/abc123',
        );
      });
    });
  });
}
