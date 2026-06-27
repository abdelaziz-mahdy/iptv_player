import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/sources/m3u_source.dart';

void main() {
  late M3uSource source;

  setUp(() {
    source = M3uSource();
  });

  group('M3uSource.parse', () {
    const singleEntryM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="news.ch1" tvg-logo="http://example.com/logo.png" group-title="News",Channel One
http://stream.example.com/channel1
''';

    const multiEntryM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="news.ch1" tvg-logo="http://example.com/logo1.png" group-title="News",Channel One
http://stream.example.com/channel1
#EXTINF:-1 tvg-id="sports.ch2" tvg-logo="http://example.com/logo2.png" group-title="Sports",Channel Two
http://stream.example.com/channel2
#EXTINF:-1 tvg-id="movies.ch3" group-title="Movies",Channel Three
http://stream.example.com/channel3
''';

    test('parses a single entry with correct name', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.length, 1);
      expect(channels.first.name, 'Channel One');
    });

    test('parses a single entry with correct streamUrl', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.first.streamUrl, 'http://stream.example.com/channel1');
    });

    test('parses a single entry with correct logoUrl', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.first.logoUrl, 'http://example.com/logo.png');
    });

    test('parses a single entry with categoryId from group-title', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.first.categoryId, 'News');
    });

    test('channel id is prefixed with playlistId', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.first.id, startsWith('pl1:'));
    });

    test('channel playlistId is set correctly', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.first.playlistId, 'pl1');
    });

    test('parses multiple entries to correct count', () async {
      final channels =
          await source.parse(multiEntryM3u, playlistId: 'playlist42');
      expect(channels.length, 3);
    });

    test('multiple entries have correct names', () async {
      final channels =
          await source.parse(multiEntryM3u, playlistId: 'playlist42');
      expect(channels[0].name, 'Channel One');
      expect(channels[1].name, 'Channel Two');
      expect(channels[2].name, 'Channel Three');
    });

    test('multiple entries all have playlistId prefix in id', () async {
      final channels =
          await source.parse(multiEntryM3u, playlistId: 'playlist42');
      for (final ch in channels) {
        expect(ch.id, startsWith('playlist42:'));
      }
    });

    test('entry without tvg-logo has null logoUrl', () async {
      final channels =
          await source.parse(multiEntryM3u, playlistId: 'playlist42');
      expect(channels[2].logoUrl, isNull);
    });

    test('number falls back to 1-based index when tvg-chno absent', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.first.number, '1');
    });

    test('number uses tvg-chno when present', () async {
      const m3uWithChno = '''
#EXTM3U
#EXTINF:-1 tvg-id="x" tvg-chno="42" group-title="Sports",Sport Channel
http://stream.example.com/sport
''';
      final channels = await source.parse(m3uWithChno, playlistId: 'pl1');
      expect(channels.first.number, '42');
    });

    test('isFavorite defaults to false', () async {
      final channels = await source.parse(singleEntryM3u, playlistId: 'pl1');
      expect(channels.first.isFavorite, isFalse);
    });

    test('channel ids are unique across multiple entries', () async {
      final channels =
          await source.parse(multiEntryM3u, playlistId: 'playlist42');
      final ids = channels.map((c) => c.id).toSet();
      expect(ids.length, channels.length);
    });
  });
}
