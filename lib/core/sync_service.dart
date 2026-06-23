import '../data/repositories/repositories.dart';

/// Refreshes the active playlist's content from its source.
///
/// Import performs the initial sync; this re-runs it (e.g. on app launch) so
/// channels/VOD/series stay current without the user re-importing.
class SyncService {
  SyncService(this._playlists, this._content);

  final PlaylistRepository _playlists;
  final ContentRepository _content;

  /// Re-imports the currently active playlist, if any. Safe to call fire-and-
  /// forget: errors are swallowed so a failed refresh never breaks startup.
  Future<void> syncActive() async {
    try {
      final active = await _playlists.active().first;
      if (active == null) return;
      await _content.importPlaylist(active);
    } catch (_) {
      // Background refresh failure is non-fatal; existing cached content stays.
    }
  }
}
