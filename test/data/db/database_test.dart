import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/data/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('replaceChannels persists and watchChannels streams them', () async {
    await db.replaceChannels('p1', [
      const ChannelsCompanion(
        id: Value('c1'),
        playlistId: Value('p1'),
        name: Value('NOOR One'),
        number: Value('101'),
        streamUrl: Value('http://x/1'),
      ),
    ]);
    final rows = await db.watchChannels('p1').first;
    expect(rows.single.name, 'NOOR One');
  });

  test('replaceChannels replaces prior rows for the playlist', () async {
    await db.replaceChannels('p1', [
      const ChannelsCompanion(
          id: Value('c1'), playlistId: Value('p1'), name: Value('A'),
          number: Value('1'), streamUrl: Value('u1')),
    ]);
    await db.replaceChannels('p1', [
      const ChannelsCompanion(
          id: Value('c2'), playlistId: Value('p1'), name: Value('B'),
          number: Value('2'), streamUrl: Value('u2')),
    ]);
    final rows = await db.watchChannels('p1').first;
    expect(rows.map((r) => r.id), ['c2']);
  });

  test('favorites add/remove and isFavorite', () async {
    expect(await db.isFavorite('movie:1'), false);
    await db.addFavorite(FavoritesCompanion(
      itemKey: const Value('movie:1'),
      playlistId: const Value('p1'),
      kind: const Value('movie'),
      addedAt: Value(DateTime.utc(2026)),
    ));
    expect(await db.isFavorite('movie:1'), true);
    await db.removeFavorite('movie:1');
    expect(await db.isFavorite('movie:1'), false);
  });

  test('watch progress upserts and continue-watching orders by recency', () async {
    await db.saveProgress(WatchProgressRowsCompanion(
      itemKey: const Value('movie:1'), playlistId: const Value('p1'),
      kind: const Value('movie'), positionSec: const Value(10),
      durationSec: const Value(100), updatedAt: Value(DateTime.utc(2026, 1, 1)),
    ));
    await db.saveProgress(WatchProgressRowsCompanion(
      itemKey: const Value('movie:2'), playlistId: const Value('p1'),
      kind: const Value('movie'), positionSec: const Value(20),
      durationSec: const Value(100), updatedAt: Value(DateTime.utc(2026, 2, 1)),
    ));
    final rows = await db.watchContinue('p1').first;
    expect(rows.map((r) => r.itemKey), ['movie:2', 'movie:1']);
    expect((await db.getProgress('movie:1'))?.positionSec, 10);
  });

  test('upsertCredentials stores and getCredentials retrieves', () async {
    await db.upsertCredentials(XtreamCredentialsCompanion.insert(
      playlistId: 'p-xtream',
      username: 'alice',
      password: 'secret',
    ));

    final row = await db.getCredentials('p-xtream');
    expect(row != null, true);
    expect(row!.username, 'alice');
    expect(row.password, 'secret');

    // Upsert updates existing row.
    await db.upsertCredentials(XtreamCredentialsCompanion.insert(
      playlistId: 'p-xtream',
      username: 'alice',
      password: 'updated',
    ));
    final updated = await db.getCredentials('p-xtream');
    expect(updated!.password, 'updated');

    // Non-existent returns null.
    expect(await db.getCredentials('no-such-id') == null, true);
  });
}
