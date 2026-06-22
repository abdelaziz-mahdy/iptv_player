import '../../core/result.dart';
import '../models/models.dart';

/// Manages the set of user playlists and which one is active.
abstract class PlaylistRepository {
  Future<Result<List<Playlist>>> all();
  Future<Result<Playlist>> add(Playlist p);
  Future<Result<void>> remove(String id);
  Stream<Playlist?> active();
  Future<void> setActive(String id);
}

/// Provides browseable content (channels, movies, series) for a playlist and
/// manages favorites. Streams are backed by the local store and update live.
abstract class ContentRepository {
  Stream<List<Channel>> channels(String playlistId);
  Stream<List<VodItem>> movies(String playlistId);
  Stream<List<Series>> series(String playlistId);
  Future<Result<List<Season>>> seasons(String seriesId);
  Future<Result<List<Episode>>> episodes(String seasonId);
  Stream<List<Favorite>> favorites(String playlistId);
  Future<void> toggleFavorite(String itemKey, String playlistId, MediaKind kind);

  /// Fetches the playlist's content from its source and persists it locally.
  Future<Result<void>> importPlaylist(Playlist p);
}

/// Reads EPG programmes for a channel within a time window.
abstract class EpgRepository {
  Future<Result<List<EpgProgramme>>> programmes(
      String channelId, DateTime from, DateTime to);
}

/// Tracks playback position and the "continue watching" list.
abstract class PlaybackRepository {
  Future<WatchProgress?> progressFor(String itemKey);
  Future<void> saveProgress(WatchProgress p);
  Stream<List<WatchProgress>> continueWatching(String playlistId);
}
