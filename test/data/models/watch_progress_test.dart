import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/models/models.dart';

WatchProgress _p({required int pos, required int dur}) => WatchProgress(
      itemKey: 'episode:e1',
      playlistId: 'p1',
      kind: MediaKind.episode,
      positionSec: pos,
      durationSec: dur,
      updatedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('WatchProgress.fraction', () {
    test('is position/duration', () {
      expect(_p(pos: 30, dur: 120).fraction, closeTo(0.25, 1e-9));
    });

    test('is null when duration is unknown (0)', () {
      expect(_p(pos: 30, dur: 0).fraction, isNull);
    });

    test('clamps to 1.0 when position overshoots duration', () {
      expect(_p(pos: 130, dur: 120).fraction, 1.0);
    });
  });

  group('WatchProgress.isWatched', () {
    test('true at or above 95%', () {
      expect(_p(pos: 114, dur: 120).isWatched, isTrue);
      expect(_p(pos: 120, dur: 120).isWatched, isTrue);
    });

    test('false below 95% with more than the credits left', () {
      expect(_p(pos: 1700, dur: 2000).isWatched, isFalse); // 85%
      expect(_p(pos: 1810, dur: 2400).isWatched, isFalse); // 10 min left
      expect(_p(pos: 0, dur: 120).isWatched, isFalse);
    });

    test('true when stopped in the end credits', () {
      // Real TV episodes: 1851/2011 s and 2413/2567 s.
      expect(_p(pos: 1851, dur: 2011).isWatched, isTrue);
      expect(_p(pos: 2413, dur: 2567).isWatched, isTrue);
    });

    test('credits rule needs 90% even for short items', () {
      expect(_p(pos: 100, dur: 120).isWatched, isFalse); // 83%, 20 s left
    });

    test('false when duration is unknown', () {
      expect(_p(pos: 500, dur: 0).isWatched, isFalse);
    });
  });
}
