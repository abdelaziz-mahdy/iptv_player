import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';

void main() {
  test('fake content repo streams seeded movies', () async {
    final repo = FakeContentRepository();
    final movies = await repo.movies('p1').first;
    expect(movies, isNotEmpty);
  });

  test('toggleFavorite adds then removes a favorite', () async {
    final repo = FakeContentRepository();
    await repo.toggleFavorite('movie:m1', 'p1', MediaKind.movie);
    expect((await repo.favorites('p1').first).length, 1);
    await repo.toggleFavorite('movie:m1', 'p1', MediaKind.movie);
    expect((await repo.favorites('p1').first), isEmpty);
  });

  test('playlist repo exposes the active seeded playlist', () async {
    final repo = FakePlaylistRepository();
    final active = await repo.active().first;
    expect(active?.id, 'p1');
  });

  test('playback repo round-trips saved progress', () async {
    final repo = FakePlaybackRepository();
    final wp = WatchProgress(
      itemKey: 'movie:m1', playlistId: 'p1', kind: MediaKind.movie,
      positionSec: 42, durationSec: 120, updatedAt: DateTime.utc(2026),
    );
    await repo.saveProgress(wp);
    expect((await repo.progressFor('movie:m1'))?.positionSec, 42);
    expect((await repo.continueWatching('p1').first).length, 1);
  });
}
