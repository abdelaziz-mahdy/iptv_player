import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/result.dart';
import 'package:noor_iptv/data/credential_store_drift.dart';
import 'package:noor_iptv/data/db/database.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/drift_content_repository.dart';
import 'package:noor_iptv/data/repositories/drift_epg_repository.dart';
import 'package:noor_iptv/data/repositories/drift_playback_repository.dart';
import 'package:noor_iptv/data/repositories/drift_playlist_repository.dart';
import 'package:noor_iptv/data/sources/m3u_source.dart';
import 'package:noor_iptv/data/sources/xtream_source.dart';

// ---------------------------------------------------------------------------
// Stub M3uSource for importPlaylist test
// ---------------------------------------------------------------------------

class _StubM3uSource extends M3uSource {
  final List<Channel> _channels;
  _StubM3uSource(this._channels);

  @override
  Future<List<Channel>> parse(String content,
      {required String playlistId}) async {
    return _channels;
  }
}

// ---------------------------------------------------------------------------
// Stub XtreamSource for xtream importPlaylist test
// ---------------------------------------------------------------------------

class _StubXtreamSource extends XtreamSource {
  final XtreamContent _content;
  _StubXtreamSource(this._content);

  @override
  Future<XtreamContent> fetchAll({
    required String serverUrl,
    required String username,
    required String password,
    required String playlistId,
  }) async {
    return _content;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

const _playlistId = 'p-test';

ChannelsCompanion _channelCompanion(String id) => ChannelsCompanion.insert(
      id: id,
      playlistId: _playlistId,
      name: 'Channel $id',
      number: '1',
      streamUrl: 'http://example.com/$id',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // 1. DriftContentRepository — channels stream reflects seeded rows
  // -------------------------------------------------------------------------
  group('DriftContentRepository.channels', () {
    test('streams rows after db.replaceChannels', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftContentRepository(db);

      // Seed two channels.
      await db.replaceChannels(
          _playlistId, [_channelCompanion('c1'), _channelCompanion('c2')]);

      final channels = await repo.channels(_playlistId).first;
      expect(channels.length, 2);
      expect(channels.map((c) => c.id), containsAll(['c1', 'c2']));
    });
  });

  // -------------------------------------------------------------------------
  // 2. toggleFavorite adds then removes (favorites stream reflects it)
  // -------------------------------------------------------------------------
  group('DriftContentRepository.toggleFavorite', () {
    test('adds then removes favorite; stream reflects both states', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftContentRepository(db);
      const key = 'movie:m1';

      // Initially empty.
      expect(await repo.favorites(_playlistId).first, isEmpty);

      // Add.
      await repo.toggleFavorite(key, _playlistId, MediaKind.movie);
      final afterAdd = await repo.favorites(_playlistId).first;
      expect(afterAdd.length, 1);
      expect(afterAdd.first.itemKey, key);

      // Remove.
      await repo.toggleFavorite(key, _playlistId, MediaKind.movie);
      final afterRemove = await repo.favorites(_playlistId).first;
      expect(afterRemove, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // 3. DriftPlaybackRepository — saveProgress / progressFor / continueWatching
  // -------------------------------------------------------------------------
  group('DriftPlaybackRepository', () {
    test('saveProgress then progressFor returns it', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaybackRepository(db);

      final wp = WatchProgress(
        itemKey: 'movie:m1',
        playlistId: _playlistId,
        kind: MediaKind.movie,
        positionSec: 42,
        durationSec: 120,
        updatedAt: DateTime.utc(2026),
      );

      await repo.saveProgress(wp);

      final result = await repo.progressFor('movie:m1');
      expect(result, isNotNull);
      expect(result!.positionSec, 42);
      expect(result.kind, MediaKind.movie);
    });

    test('continueWatching streams saved progress', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaybackRepository(db);

      final wp = WatchProgress(
        itemKey: 'movie:m1',
        playlistId: _playlistId,
        kind: MediaKind.movie,
        positionSec: 10,
        durationSec: 60,
        updatedAt: DateTime.utc(2026),
      );

      await repo.saveProgress(wp);

      final list = await repo.continueWatching(_playlistId).first;
      expect(list.length, 1);
      expect(list.first.itemKey, 'movie:m1');
    });

    test('continueWatching excludes channel-kind entries', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaybackRepository(db);

      // Save a channel entry and a movie entry.
      await repo.saveProgress(WatchProgress(
        itemKey: 'channel:c1',
        playlistId: _playlistId,
        kind: MediaKind.channel,
        positionSec: 10,
        durationSec: 60,
        updatedAt: DateTime.utc(2026, 1, 1),
      ));
      await repo.saveProgress(WatchProgress(
        itemKey: 'movie:m1',
        playlistId: _playlistId,
        kind: MediaKind.movie,
        positionSec: 42,
        durationSec: 120,
        updatedAt: DateTime.utc(2026, 1, 2),
      ));

      final list = await repo.continueWatching(_playlistId).first;
      expect(list, hasLength(1));
      expect(list.first.itemKey, 'movie:m1');
      expect(list.first.kind, MediaKind.movie);
    });

    test('continueWatching caps at 20 most-recent entries', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaybackRepository(db);

      // Save 25 movie entries with increasing updatedAt.
      for (var i = 1; i <= 25; i++) {
        await repo.saveProgress(WatchProgress(
          itemKey: 'movie:m$i',
          playlistId: _playlistId,
          kind: MediaKind.movie,
          positionSec: i,
          durationSec: 100,
          updatedAt: DateTime.utc(2026, 1, i),
        ));
      }

      final list = await repo.continueWatching(_playlistId).first;
      expect(list, hasLength(20));
      // Most recent should be first (m25 updatedAt is largest).
      expect(list.first.itemKey, 'movie:m25');
    });

    test('removeProgress deletes the row; progressFor returns null', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaybackRepository(db);

      await repo.saveProgress(WatchProgress(
        itemKey: 'movie:m1',
        playlistId: _playlistId,
        kind: MediaKind.movie,
        positionSec: 42,
        durationSec: 120,
        updatedAt: DateTime.utc(2026),
      ));

      // Confirm it exists.
      expect(await repo.progressFor('movie:m1'), isNotNull);

      // Remove it.
      await repo.removeProgress('movie:m1');

      // Should be gone.
      expect(await repo.progressFor('movie:m1'), isNull);

      // continueWatching stream should also be empty.
      final list = await repo.continueWatching(_playlistId).first;
      expect(list, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // 4. DriftPlaylistRepository — add / all / active
  // -------------------------------------------------------------------------
  group('DriftPlaylistRepository', () {
    test('add then all() returns it', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaylistRepository(db);

      const p = Playlist(
        id: _playlistId,
        name: 'My Playlist',
        type: PlaylistType.m3u,
        serverUrl: null,
        initial: 'M',
      );

      final addResult = await repo.add(p);
      expect(addResult, isA<Ok<Playlist>>());

      final allResult = await repo.all();
      expect(allResult, isA<Ok<List<Playlist>>>());
      final all = (allResult as Ok<List<Playlist>>).value;
      expect(all.length, 1);
      expect(all.first.id, _playlistId);
    });

    test('active() emits the added playlist', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaylistRepository(db);

      const p = Playlist(
        id: _playlistId,
        name: 'Active Playlist',
        type: PlaylistType.m3u,
        serverUrl: null,
        initial: 'A',
      );

      await repo.add(p);

      // Collect the first non-null emission from active().
      final active = await repo.active().firstWhere((x) => x != null);
      expect(active?.id, _playlistId);
    });

    test('setActive updates the active stream', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftPlaylistRepository(db);

      const p1 = Playlist(
          id: 'pl-1', name: 'PL1', type: PlaylistType.m3u, initial: 'P');
      const p2 = Playlist(
          id: 'pl-2', name: 'PL2', type: PlaylistType.m3u, initial: 'Q');

      await repo.add(p1);
      await repo.add(p2);
      await repo.setActive('pl-2');

      // The next emission of active() should be pl-2.
      final active = await repo.active().firstWhere((x) => x?.id == 'pl-2');
      expect(active?.id, 'pl-2');
    });
  });

  // -------------------------------------------------------------------------
  // 5. importPlaylist for m3u — stub M3uSource, assert channels persisted
  // -------------------------------------------------------------------------
  group('DriftContentRepository.importPlaylist (m3u)', () {
    test('channels are persisted via stub M3uSource', () async {
      final db = _makeDb();
      addTearDown(db.close);

      const p = Playlist(
        id: _playlistId,
        name: 'M3U Playlist',
        type: PlaylistType.m3u,
        serverUrl: 'http://example.com/playlist.m3u',
        initial: 'M',
      );

      final stubChannels = [
        const Channel(
            id: 'stub-c1',
            playlistId: _playlistId,
            name: 'Stub Ch 1',
            number: '1',
            streamUrl: 'http://example.com/1'),
        const Channel(
            id: 'stub-c2',
            playlistId: _playlistId,
            name: 'Stub Ch 2',
            number: '2',
            streamUrl: 'http://example.com/2'),
      ];

      // Fake Dio that returns an empty body (the stub M3uSource ignores it).
      final fakeDio = _FakeDio('');

      final repo = DriftContentRepository(
        db,
        dio: fakeDio,
        m3u: _StubM3uSource(stubChannels),
      );

      final result = await repo.importPlaylist(p);
      expect(result, isA<Ok<void>>());

      final channelStream = await repo.channels(_playlistId).first;
      expect(channelStream.length, 2);
      expect(channelStream.map((c) => c.id),
          containsAll(['stub-c1', 'stub-c2']));
    });
  });

  // -------------------------------------------------------------------------
  // 6. EpgRepositoryImpl — programmes returns Ok with mapped data
  // -------------------------------------------------------------------------
  group('EpgRepositoryImpl', () {
    test('programmes returns Ok with EPG rows', () async {
      final db = _makeDb();
      addTearDown(db.close);

      // Seed an EPG row.
      final now = DateTime.utc(2026, 6, 1, 10);
      final stop = now.add(const Duration(hours: 1));
      await db.upsertEpg([
        EpgProgrammesCompanion.insert(
          id: 'epg-1',
          channelId: 'ch1',
          title: 'News',
          startUtc: now,
          stopUtc: stop,
          description: const Value(null),
        ),
      ]);

      final repo = EpgRepositoryImpl(db);
      final result = await repo.programmes(
        'ch1',
        now.subtract(const Duration(minutes: 1)),
        stop.add(const Duration(minutes: 1)),
      );

      expect(result, isA<Ok<List<EpgProgramme>>>());
      final progs = (result as Ok<List<EpgProgramme>>).value;
      expect(progs.length, 1);
      expect(progs.first.title, 'News');
    });
  });

  // -------------------------------------------------------------------------
  // 7. DriftContentRepository.categories — reads from db after seed
  // -------------------------------------------------------------------------
  group('DriftContentRepository.categories', () {
    test('returns mapped CategoryRefs from seeded db rows', () async {
      final db = _makeDb();
      addTearDown(db.close);

      // Seed two vod categories directly into the db.
      await db.replaceCategories(_playlistId, 'vod', [
        CategoriesCompanion.insert(
            playlistId: _playlistId, type: 'vod', categoryId: '1', name: 'Action'),
        CategoriesCompanion.insert(
            playlistId: _playlistId, type: 'vod', categoryId: '2', name: 'Drama'),
      ]);

      final repo = DriftContentRepository(db);
      final result = await repo.categories(_playlistId, MediaKind.movie);

      expect(result.length, 2);
      expect(result.map((r) => r.name), containsAll(['Action', 'Drama']));
    });

    test('returns empty list when no categories seeded (m3u case)', () async {
      final db = _makeDb();
      addTearDown(db.close);

      final repo = DriftContentRepository(db);
      final result = await repo.categories(_playlistId, MediaKind.movie);
      expect(result, isEmpty);
    });

    test('maps MediaKind.channel to live type', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await db.replaceCategories(_playlistId, 'live', [
        CategoriesCompanion.insert(
            playlistId: _playlistId, type: 'live', categoryId: '10', name: 'Sports'),
      ]);

      final repo = DriftContentRepository(db);
      final result = await repo.categories(_playlistId, MediaKind.channel);
      expect(result.single.name, 'Sports');
    });

    test('maps MediaKind.episode to series type', () async {
      final db = _makeDb();
      addTearDown(db.close);

      await db.replaceCategories(_playlistId, 'series', [
        CategoriesCompanion.insert(
            playlistId: _playlistId, type: 'series', categoryId: '20', name: 'Sci-Fi'),
      ]);

      final repo = DriftContentRepository(db);
      final result = await repo.categories(_playlistId, MediaKind.episode);
      expect(result.single.name, 'Sci-Fi');
    });
  });

  // -------------------------------------------------------------------------
  // 8. DriftContentRepository.importPlaylist (xtream) — credentials from
  //    DriftCredentialStore, stub XtreamSource, channels persisted
  // -------------------------------------------------------------------------
  group('DriftContentRepository.importPlaylist (xtream)', () {
    test('channels persisted when credentials are pre-saved in DriftCredentialStore',
        () async {
      final db = _makeDb();
      addTearDown(db.close);

      // Use the SAME db for both the credential store and content repo —
      // this mirrors the production DI wiring.
      final credStore = DriftCredentialStore(db);

      const playlistId = 'xtream-pl';
      const serverUrl = 'http://xtream.example.com';

      // Pre-save credentials (simulates what ImportCubit does on write path).
      await credStore.save(
        playlistId,
        username: 'alice',
        password: 'secret',
      );

      // Build stub content to be returned by the XtreamSource.
      final stubChannels = [
        const Channel(
          id: 'xtream-pl:live:1',
          playlistId: playlistId,
          name: 'Live Ch 1',
          number: '1',
          streamUrl: 'http://xtream.example.com/alice/secret/1.ts',
        ),
        const Channel(
          id: 'xtream-pl:live:2',
          playlistId: playlistId,
          name: 'Live Ch 2',
          number: '2',
          streamUrl: 'http://xtream.example.com/alice/secret/2.ts',
        ),
      ];

      final stubContent = XtreamContent(
        channels: stubChannels,
        movies: [],
        series: [],
      );

      final repo = DriftContentRepository(
        db,
        credentialStore: credStore,
        xtream: _StubXtreamSource(stubContent),
      );

      const playlist = Playlist(
        id: playlistId,
        name: 'XTV',
        type: PlaylistType.xtream,
        serverUrl: serverUrl,
        initial: 'X',
      );

      final result = await repo.importPlaylist(playlist);
      expect(result, isA<Ok<void>>());

      final channels = await repo.channels(playlistId).first;
      expect(channels.length, 2);
      expect(channels.map((c) => c.id),
          containsAll(['xtream-pl:live:1', 'xtream-pl:live:2']));
    });

    test('returns Err when credentials are missing', () async {
      final db = _makeDb();
      addTearDown(db.close);

      // No credentials saved — repo should return Err.
      final repo = DriftContentRepository(
        db,
        credentialStore: DriftCredentialStore(db),
        xtream: _StubXtreamSource(
          const XtreamContent(channels: [], movies: [], series: []),
        ),
      );

      const playlist = Playlist(
        id: 'no-creds-pl',
        name: 'NoCreds',
        type: PlaylistType.xtream,
        serverUrl: 'http://xtream.example.com',
        initial: 'N',
      );

      final result = await repo.importPlaylist(playlist);
      expect(result, isA<Err<void>>());
      final err = result as Err<void>;
      expect(err.failure.message, contains('credentials missing'));
    });
  });
}

// ---------------------------------------------------------------------------
// A minimal fake Dio that returns a predetermined body for GET requests.
// ---------------------------------------------------------------------------

class _FakeDio extends Fake implements Dio {
  _FakeDio(this._body);

  final String _body;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    return Response<T>(
      data: _body as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}
