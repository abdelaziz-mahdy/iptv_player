import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/features/home/home_screen.dart';

void main() {
  group('resolveContinueWatchingSeriesRef', () {
    test('episode key resolves to series id + season number', () {
      final (seriesId, season) = resolveContinueWatchingSeriesRef(
        'episode:pl_1:series:67:season:3:ep:912',
      );
      expect(seriesId, 'pl_1:series:67');
      expect(season, '3');
    });

    test('direct series key resolves to series id, no season', () {
      final (seriesId, season) =
          resolveContinueWatchingSeriesRef('series:pl_1:series:67');
      expect(seriesId, 'pl_1:series:67');
      expect(season, isNull);
    });

    test('movie key returns null (falls through to movie branch)', () {
      final (seriesId, season) =
          resolveContinueWatchingSeriesRef('movie:m123');
      expect(seriesId, isNull);
      expect(season, isNull);
    });

    test('channel key returns null', () {
      final (seriesId, season) =
          resolveContinueWatchingSeriesRef('channel:c1');
      expect(seriesId, isNull);
      expect(season, isNull);
    });
  });
}
