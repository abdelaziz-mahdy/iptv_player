import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/result.dart';
import 'package:noor_iptv/data/models/models.dart';

void main() {
  test('Result.when dispatches ok/err', () {
    const Result<int> ok = Ok(5);
    const Result<int> err = Err(Failure('boom'));
    expect(ok.when(ok: (v) => 'v$v', err: (f) => f.message), 'v5');
    expect(err.when(ok: (v) => 'v$v', err: (f) => f.message), 'boom');
  });

  test('Channel json round-trips', () {
    const c = Channel(
        id: '1',
        playlistId: 'p',
        name: 'BBC',
        number: '101',
        logoUrl: null,
        streamUrl: 'http://x',
        categoryId: 'news',
        isFavorite: false);
    expect(Channel.fromJson(c.toJson()), c);
  });

  test('EpgProgramme preserves DateTimes through json', () {
    final e = EpgProgramme(
      id: 'e1',
      channelId: 'c1',
      title: 'News',
      startUtc: DateTime.utc(2026, 6, 21, 20),
      stopUtc: DateTime.utc(2026, 6, 21, 21),
    );
    expect(EpgProgramme.fromJson(e.toJson()), e);
  });

  test('WatchProgress carries kind enum', () {
    final w = WatchProgress(
      itemKey: 'movie:1',
      playlistId: 'p',
      kind: MediaKind.movie,
      positionSec: 30,
      durationSec: 120,
      updatedAt: DateTime.utc(2026, 6, 21),
    );
    expect(WatchProgress.fromJson(w.toJson()), w);
  });
}
