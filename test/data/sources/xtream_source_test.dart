import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/sources/xtream_source.dart';
import 'package:xtream_code_client/xtream_code_client.dart'
    as xc
    show LiveStreamItem, VodItem, SeriesItem;

void main() {
  const playlistId = 'pl1';
  const serverUrl = 'http://example.com:8080';
  const username = 'user';
  const password = 'pass';

  // -------------------------------------------------------------------------
  // channelFromLive
  // -------------------------------------------------------------------------

  group('channelFromLive', () {
    test('id is prefixed with playlistId:live:', () {
      const item = xc.LiveStreamItem(streamId: 42);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.id, 'pl1:live:42');
    });

    test('playlistId is set on the channel', () {
      const item = xc.LiveStreamItem(streamId: 1);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.playlistId, playlistId);
    });

    test('streamUrl is non-empty and contains stream id', () {
      const item = xc.LiveStreamItem(streamId: 7);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.streamUrl, isNotEmpty);
      expect(ch.streamUrl, contains('7'));
    });

    test('streamUrl follows {server}/{user}/{pass}/{id}.ts convention', () {
      const item = xc.LiveStreamItem(streamId: 7);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.streamUrl, 'http://example.com:8080/live/user/pass/7.ts');
    });

    test('number uses item.num when present', () {
      const item = xc.LiveStreamItem(streamId: 1, num: 5);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.number, '5');
    });

    test('number falls back to 1-based index when num is null', () {
      const item = xc.LiveStreamItem(streamId: 1);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 2,
      );
      expect(ch.number, '3');
    });

    test('logoUrl is null when streamIcon is null', () {
      const item = xc.LiveStreamItem(streamId: 1);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.logoUrl, isNull);
    });

    test('logoUrl is null when streamIcon is empty string', () {
      const item = xc.LiveStreamItem(streamId: 1, streamIcon: '');
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.logoUrl, isNull);
    });

    test('logoUrl is set from streamIcon', () {
      const item = xc.LiveStreamItem(
        streamId: 1,
        streamIcon: 'http://example.com/logo.png',
      );
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.logoUrl, 'http://example.com/logo.png');
    });

    test('categoryId is stringified from int categoryId', () {
      const item = xc.LiveStreamItem(streamId: 1, categoryId: 99);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.categoryId, '99');
    });

    test('categoryId is null when item has no categoryId', () {
      const item = xc.LiveStreamItem(streamId: 1);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.categoryId, isNull);
    });

    test('trailing slash on serverUrl is stripped in stream URL', () {
      const item = xc.LiveStreamItem(streamId: 3);
      final ch = channelFromLive(
        item,
        playlistId: playlistId,
        serverUrl: 'http://example.com:8080/',
        username: username,
        password: password,
        index: 0,
      );
      expect(ch.streamUrl, 'http://example.com:8080/live/user/pass/3.ts');
    });
  });

  // -------------------------------------------------------------------------
  // vodItemFromXtream
  // -------------------------------------------------------------------------

  group('vodItemFromXtream', () {
    test('id is prefixed with playlistId:vod:', () {
      const item = xc.VodItem(streamId: 10);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.id, 'pl1:vod:10');
    });

    test('streamUrl follows {server}/movie/{user}/{pass}/{id}.mp4 by default',
        () {
      const item = xc.VodItem(streamId: 10);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.streamUrl, 'http://example.com:8080/movie/user/pass/10.mp4');
    });

    test('streamUrl uses containerExtension from item when present', () {
      const item = xc.VodItem(streamId: 10, containerExtension: 'mkv');
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.streamUrl, 'http://example.com:8080/movie/user/pass/10.mkv');
    });

    test('year is mapped from item.year', () {
      const item = xc.VodItem(streamId: 10, year: '2021');
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.year, '2021');
    });

    test('year is null when item.year is null', () {
      const item = xc.VodItem(streamId: 10);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.year, isNull);
    });

    test('year is null when item.year is empty string', () {
      const item = xc.VodItem(streamId: 10, year: '');
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.year, isNull);
    });

    test('rating is mapped from item.rating double', () {
      const item = xc.VodItem(streamId: 10, rating: 7.5);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.rating, 7.5);
    });

    test('rating is null when item.rating is null', () {
      const item = xc.VodItem(streamId: 10);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.rating, isNull);
    });

    test('title prefers item.title over item.name', () {
      const item = xc.VodItem(streamId: 10, name: 'Name', title: 'Title');
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.title, 'Title');
    });

    test('title falls back to item.name when title is null', () {
      const item = xc.VodItem(streamId: 10, name: 'FallbackName');
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.title, 'FallbackName');
    });

    test('posterUrl is set from streamIcon', () {
      const item = xc.VodItem(
        streamId: 10,
        streamIcon: 'http://example.com/poster.jpg',
      );
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.posterUrl, 'http://example.com/poster.jpg');
    });

    test('posterUrl is null when streamIcon is null', () {
      const item = xc.VodItem(streamId: 10);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.posterUrl, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // seriesFromXtream
  // -------------------------------------------------------------------------

  group('seriesFromXtream', () {
    test('id is prefixed with playlistId:series:', () {
      const item = xc.SeriesItem(seriesId: 55);
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.id, 'pl1:series:55');
    });

    test('playlistId is set on the series', () {
      const item = xc.SeriesItem(seriesId: 55);
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.playlistId, playlistId);
    });

    test('title prefers item.title over item.name', () {
      const item = xc.SeriesItem(
        seriesId: 1,
        name: 'Name',
        title: 'Title',
      );
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.title, 'Title');
    });

    test('title falls back to item.name when title is null', () {
      const item = xc.SeriesItem(seriesId: 1, name: 'SeriesName');
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.title, 'SeriesName');
    });

    test('posterUrl is set from cover', () {
      const item = xc.SeriesItem(
        seriesId: 1,
        cover: 'http://example.com/cover.jpg',
      );
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.posterUrl, 'http://example.com/cover.jpg');
    });

    test('posterUrl is null when cover is null', () {
      const item = xc.SeriesItem(seriesId: 1);
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.posterUrl, isNull);
    });

    test('year is mapped from item.year', () {
      const item = xc.SeriesItem(seriesId: 1, year: '2019');
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.year, '2019');
    });

    test('rating is mapped from item.rating', () {
      const item = xc.SeriesItem(seriesId: 1, rating: 8.2);
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.rating, 8.2);
    });

    test('rating is null when item.rating is null', () {
      const item = xc.SeriesItem(seriesId: 1);
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.rating, isNull);
    });

    test('categoryId is stringified from int', () {
      const item = xc.SeriesItem(seriesId: 1, categoryId: 7);
      final series = seriesFromXtream(item, playlistId: playlistId);
      expect(series.categoryId, '7');
    });
  });

  // -------------------------------------------------------------------------
  // _safeRating — tested indirectly via the mapping helpers
  // -------------------------------------------------------------------------

  group('rating safety (via vodItemFromXtream)', () {
    test('null rating stays null', () {
      const item = xc.VodItem(streamId: 1);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.rating, isNull);
    });

    test('valid double rating is preserved', () {
      const item = xc.VodItem(streamId: 1, rating: 6.8);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.rating, 6.8);
    });

    test('zero rating is preserved', () {
      const item = xc.VodItem(streamId: 1, rating: 0.0);
      final vod = vodItemFromXtream(
        item,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
      expect(vod.rating, 0.0);
    });
  });
}
