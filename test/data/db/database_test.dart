import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/db/database.dart';

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

  test('replaceCategories stores and getCategories retrieves by type', () async {
    await db.replaceCategories('p1', 'vod', [
      CategoriesCompanion.insert(playlistId: 'p1', type: 'vod', categoryId: '407', name: 'Action'),
    ]);
    final rows = await db.getCategories('p1', 'vod');
    expect(rows.single.name, 'Action');
    expect(await db.getCategories('p1', 'live'), isEmpty);
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

  group('recently viewed', () {
    Future<void> view(String key, DateTime at) => db.recordRecentlyViewed(
          RecentlyViewedRowsCompanion.insert(
            itemKey: key,
            playlistId: 'p1',
            viewedAt: at,
          ),
        );

    test('the prefix filter and limit are per kind, not shared', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      await view('channel:c1', t0);
      for (var i = 0; i < 30; i++) {
        await view('movie:m$i', t0.add(Duration(minutes: i + 1)));
      }

      // A movie binge must not evict the channel: each kind gets its own cap.
      final channels =
          await db.watchRecentlyViewed('p1', 'channel:', 20).first;
      expect(channels.map((r) => r.itemKey), ['channel:c1']);

      final movies = await db.watchRecentlyViewed('p1', 'movie:', 20).first;
      expect(movies.length, 20);
      expect(movies.first.itemKey, 'movie:m29', reason: 'newest first');
    });

    test('re-viewing an item moves it to the front', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      await view('movie:a', t0);
      await view('movie:b', t0.add(const Duration(minutes: 1)));
      await view('movie:a', t0.add(const Duration(minutes: 2)));

      final rows = await db.watchRecentlyViewed('p1', 'movie:', 20).first;
      expect(rows.map((r) => r.itemKey), ['movie:a', 'movie:b']);
    });
  });

  group('categories', () {
    test('getCategories returns the provider order, name as tie-break',
        () async {
      await db.replaceCategories('p1', 'live', [
        CategoriesCompanion.insert(
            playlistId: 'p1',
            type: 'live',
            categoryId: 'c-sport',
            name: 'Sports',
            position: const Value(0)),
        CategoriesCompanion.insert(
            playlistId: 'p1',
            type: 'live',
            categoryId: 'c-news',
            name: 'News',
            position: const Value(1)),
        // Legacy rows (imported before `position` existed) all carry 0.
        CategoriesCompanion.insert(
            playlistId: 'p1', type: 'live', categoryId: 'c-a', name: 'Aaa'),
      ]);

      final rows = await db.getCategories('p1', 'live');
      expect(rows.map((r) => r.categoryId), ['c-a', 'c-sport', 'c-news']);
    });

    test('category use is recorded most-recent-first', () async {
      Future<void> use(String id, DateTime at) => db.recordCategoryUse(
            CategoryUsageRowsCompanion.insert(
              playlistId: 'p1',
              type: 'live',
              categoryId: id,
              usedAt: at,
            ),
          );
      final t0 = DateTime.utc(2026, 1, 1);
      await use('c1', t0);
      await use('c2', t0.add(const Duration(minutes: 1)));
      await use('c1', t0.add(const Duration(minutes: 2)));

      final rows = await db.watchCategoryUse('p1', 'live').first;
      expect(rows.map((r) => r.categoryId), ['c1', 'c2']);
    });
  });
}
