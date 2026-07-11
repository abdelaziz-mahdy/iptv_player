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

    test('false below 95%', () {
      expect(_p(pos: 113, dur: 120).isWatched, isFalse);
      expect(_p(pos: 0, dur: 120).isWatched, isFalse);
    });

    test('false when duration is unknown', () {
      expect(_p(pos: 500, dur: 0).isWatched, isFalse);
    });
  });
}
