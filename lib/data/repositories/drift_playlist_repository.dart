import 'dart:async';

import 'package:drift/drift.dart' show Value;

import '../../core/result.dart';
import '../db/database.dart';
import '../models/models.dart';
import 'repositories.dart';

/// Drift-backed [PlaylistRepository].
///
/// The active playlist is tracked in memory as a broadcast
/// [StreamController] so that callers receive the current value immediately
/// on subscription, and subsequent updates are forwarded to all listeners.
class DriftPlaylistRepository implements PlaylistRepository {
  DriftPlaylistRepository(this._db);

  final AppDatabase _db;

  String? _activeId;
  final _activeCtrl = StreamController<Playlist?>.broadcast();

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  static Playlist _fromRow(PlaylistRow r) => Playlist(
        id: r.id,
        name: r.name,
        type: PlaylistType.values.byName(r.type),
        serverUrl: r.serverUrl,
        initial: r.initial,
        channelCount: r.channelCount,
      );

  static PlaylistsCompanion _toCompanion(Playlist p) => PlaylistsCompanion.insert(
        id: p.id,
        name: p.name,
        type: p.type.name,
        serverUrl: Value(p.serverUrl),
        initial: p.initial,
        channelCount: Value(p.channelCount),
      );

  // ---------------------------------------------------------------------------
  // PlaylistRepository
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Playlist>>> all() async {
    try {
      final rows = await _db.getPlaylists();
      return Ok(rows.map(_fromRow).toList());
    } catch (e) {
      return Err(Failure('Failed to load playlists', cause: e));
    }
  }

  @override
  Future<Result<Playlist>> add(Playlist p) async {
    try {
      await _db.upsertPlaylist(_toCompanion(p));
      // Seed the active id if this is the first playlist being added.
      if (_activeId == null) {
        _activeId = p.id;
        _activeCtrl.add(p);
      }
      return Ok(p);
    } catch (e) {
      return Err(Failure('Failed to add playlist', cause: e));
    }
  }

  @override
  Future<Result<void>> remove(String id) async {
    try {
      await _db.deletePlaylist(id);
      if (_activeId == id) {
        // Try to fall back to another playlist.
        final rows = await _db.getPlaylists();
        _activeId = rows.isEmpty ? null : rows.first.id;
        _activeCtrl.add(rows.isEmpty ? null : _fromRow(rows.first));
      }
      return const Ok(null);
    } catch (e) {
      return Err(Failure('Failed to remove playlist', cause: e));
    }
  }

  @override
  Stream<Playlist?> active() async* {
    // Emit current value immediately.
    if (_activeId == null) {
      // Attempt to initialise from the DB on first subscription.
      try {
        final rows = await _db.getPlaylists();
        if (rows.isNotEmpty) {
          _activeId = rows.first.id;
          yield _fromRow(rows.first);
        } else {
          yield null;
        }
      } catch (_) {
        yield null;
      }
    } else {
      try {
        final rows = await _db.getPlaylists();
        final match = rows.where((r) => r.id == _activeId).firstOrNull;
        yield match == null ? null : _fromRow(match);
      } catch (_) {
        yield null;
      }
    }
    yield* _activeCtrl.stream;
  }

  @override
  Future<void> setActive(String id) async {
    _activeId = id;
    try {
      final rows = await _db.getPlaylists();
      final match = rows.where((r) => r.id == id).firstOrNull;
      _activeCtrl.add(match == null ? null : _fromRow(match));
    } catch (_) {
      _activeCtrl.add(null);
    }
  }
}
