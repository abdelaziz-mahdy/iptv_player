import '../db/database.dart';
import '../models/models.dart';
import 'repositories.dart';

/// Drift-backed [PlaybackRepository].
class DriftPlaybackRepository implements PlaybackRepository {
  DriftPlaybackRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  static WatchProgress _fromRow(WatchProgressRow r) => WatchProgress(
        itemKey: r.itemKey,
        playlistId: r.playlistId,
        kind: MediaKind.values.byName(r.kind),
        positionSec: r.positionSec,
        durationSec: r.durationSec,
        updatedAt: r.updatedAt,
      );

  static WatchProgressRowsCompanion _toCompanion(WatchProgress p) =>
      WatchProgressRowsCompanion.insert(
        itemKey: p.itemKey,
        playlistId: p.playlistId,
        kind: p.kind.name,
        positionSec: p.positionSec,
        durationSec: p.durationSec,
        updatedAt: p.updatedAt,
      );

  // ---------------------------------------------------------------------------
  // PlaybackRepository
  // ---------------------------------------------------------------------------

  @override
  Future<WatchProgress?> progressFor(String itemKey) async {
    final row = await _db.getProgress(itemKey);
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> saveProgress(WatchProgress p) async {
    await _db.saveProgress(_toCompanion(p));
  }

  @override
  Future<void> removeProgress(String itemKey) async {
    await _db.deleteProgress(itemKey);
  }

  @override
  Stream<List<WatchProgress>> continueWatching(String playlistId) {
    return _db.watchContinue(playlistId).map(
          (rows) => rows.map(_fromRow).toList(),
        );
  }

  @override
  Future<void> recordView({
    required String playlistId,
    required String itemKey,
  }) {
    return _db.recordRecentlyViewed(
      RecentlyViewedRowsCompanion.insert(
        itemKey: itemKey,
        playlistId: playlistId,
        viewedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Stream<List<String>> recentlyViewed(String playlistId) {
    return _db.watchRecentlyViewed(playlistId).map(
          (rows) => rows.map((r) => r.itemKey).toList(),
        );
  }
}
