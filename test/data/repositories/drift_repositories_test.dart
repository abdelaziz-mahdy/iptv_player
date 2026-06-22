import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/result.dart';
import 'package:noor_iptv/data/db/database.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/drift_content_repository.dart';
import 'package:noor_iptv/data/repositories/drift_epg_repository.dart';
import 'package:noor_iptv/data/repositories/drift_playback_repository.dart';
import 'package:noor_iptv/data/repositories/drift_playlist_repository.dart';
import 'package:noor_iptv/data/sources/m3u_source.dart';

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
        itemKey: 'channel:c1',
        playlistId: _playlistId,
        kind: MediaKind.channel,
        positionSec: 10,
        durationSec: 60,
        updatedAt: DateTime.utc(2026),
      );

      await repo.saveProgress(wp);

      final list = await repo.continueWatching(_playlistId).first;
      expect(list.length, 1);
      expect(list.first.itemKey, 'channel:c1');
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
