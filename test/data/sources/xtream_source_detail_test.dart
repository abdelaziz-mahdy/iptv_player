import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/sources/xtream_source.dart';
import 'package:xtream_code_client/xtream_code_client.dart'
    as xc
    show Season, Episode, EpisodeInfo;

void main() {
  const playlistId = 'pl1';
  const serverUrl = 'http://example.com:8080';
  const username = 'user';
  const password = 'pass';

  group('seasonFromXtreamSeason', () {
    test('id is prefixed correctly', () {
      const xcSeason = xc.Season(seasonNumber: 3);
      final s = seasonFromXtreamSeason(
        xcSeason,
        seriesId: '99',
        playlistId: playlistId,
      );
      expect(s.id, 'pl1:series:99:season:3');
    });

    test('seriesId is the full prefixed series id', () {
      const xcSeason = xc.Season(seasonNumber: 1);
      final s = seasonFromXtreamSeason(
        xcSeason,
        seriesId: '5',
        playlistId: playlistId,
      );
      expect(s.seriesId, 'pl1:series:5');
    });

    test('number is seasonNumber', () {
      const xcSeason = xc.Season(seasonNumber: 2);
      final s = seasonFromXtreamSeason(
        xcSeason,
        seriesId: '5',
        playlistId: playlistId,
      );
      expect(s.number, 2);
    });

    test('number defaults to 1 when seasonNumber is null', () {
      const xcSeason = xc.Season();
      final s = seasonFromXtreamSeason(
        xcSeason,
        seriesId: '5',
        playlistId: playlistId,
      );
      expect(s.number, 1);
    });
  });

  group('seriesDetailFromXtreamInfo', () {
    xc.Episode ep(int id, int num) => xc.Episode(
          id: id,
          episodeNum: num,
          containerExtension: 'mp4',
          info: const xc.EpisodeInfo(),
        );

    test('drops seasons advertised in metadata that have no episodes', () {
      // Provider lists 4 seasons (related shows grouped together) but only
      // ships episodes for seasons 1 and 2.
      final detail = seriesDetailFromXtreamInfo(
        xcSeasons: const [
          xc.Season(seasonNumber: 1),
          xc.Season(seasonNumber: 2),
          xc.Season(seasonNumber: 3),
          xc.Season(seasonNumber: 4),
        ],
        xcEpisodeMap: {
          '1': [ep(11, 1), ep(12, 2)],
          '2': [ep(21, 1)],
        },
        seriesId: '901',
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(detail.seasons.map((s) => s.number), [1, 2]);
      expect(detail.episodesBySeason.keys, hasLength(2));
    });

    test('keeps seasons that exist only in the episodes map', () {
      final detail = seriesDetailFromXtreamInfo(
        xcSeasons: const [],
        xcEpisodeMap: {
          '3': [ep(31, 1)],
        },
        seriesId: '901',
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(detail.seasons.map((s) => s.number), [3]);
      expect(detail.episodesBySeason['pl1:series:901:season:3'], hasLength(1));
    });

    test('drops seasons whose episode list is present but empty', () {
      final detail = seriesDetailFromXtreamInfo(
        xcSeasons: const [],
        xcEpisodeMap: {
          '1': [ep(11, 1)],
          '2': const [],
        },
        seriesId: '901',
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(detail.seasons.map((s) => s.number), [1]);
    });
  });

  group('episodeFromXtreamEpisode', () {
    test('id is prefixed as seasonId:ep:episodeId', () {
      const xcEp = xc.Episode(
        id: 777,
        episodeNum: 1,
        containerExtension: 'mp4',
        info: xc.EpisodeInfo(),
      );
      final e = episodeFromXtreamEpisode(
        xcEp,
        seasonId: 'pl1:series:5:season:1',
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(e.id, 'pl1:series:5:season:1:ep:777');
    });

    test('seasonId is set correctly', () {
      const xcEp = xc.Episode(
        id: 1,
        episodeNum: 2,
        containerExtension: 'ts',
        info: xc.EpisodeInfo(),
      );
      final e = episodeFromXtreamEpisode(
        xcEp,
        seasonId: 'pl1:series:9:season:2',
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(e.seasonId, 'pl1:series:9:season:2');
    });

    test('streamUrl follows {server}/series/{user}/{pass}/{id}.{ext}', () {
      const xcEp = xc.Episode(
        id: 42,
        episodeNum: 3,
        containerExtension: 'mkv',
        info: xc.EpisodeInfo(),
      );
      final e = episodeFromXtreamEpisode(
        xcEp,
        seasonId: 'pl1:series:5:season:1',
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(e.streamUrl, 'http://example.com:8080/series/user/pass/42.mkv');
    });

    test('streamUrl defaults to mp4 when containerExtension is null', () {
      const xcEp = xc.Episode(
        id: 10,
        episodeNum: 1,
        info: xc.EpisodeInfo(),
      );
      final e = episodeFromXtreamEpisode(
        xcEp,
        seasonId: 'pl1:series:5:season:1',
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(e.streamUrl, contains('10.mp4'));
    });

    test('number is episodeNum', () {
      const xcEp = xc.Episode(
        id: 1,
        episodeNum: 7,
        containerExtension: 'mp4',
        info: xc.EpisodeInfo(),
      );
      final e = episodeFromXtreamEpisode(
        xcEp,
        seasonId: 'pl1:series:5:season:1',
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(e.number, 7);
    });

    test('title is episode title when present', () {
      const xcEp = xc.Episode(
        id: 1,
        episodeNum: 1,
        title: 'Pilot',
        containerExtension: 'mp4',
        info: xc.EpisodeInfo(),
      );
      final e = episodeFromXtreamEpisode(
        xcEp,
        seasonId: 'pl1:series:5:season:1',
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(e.title, 'Pilot');
    });

    test('durationSec comes from info.durationSecs', () {
      const xcEp = xc.Episode(
        id: 1,
        episodeNum: 1,
        containerExtension: 'mp4',
        info: xc.EpisodeInfo(durationSecs: 2700),
      );
      final e = episodeFromXtreamEpisode(
        xcEp,
        seasonId: 'pl1:series:5:season:1',
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(e.durationSec, 2700);
    });
  });
}
