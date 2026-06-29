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

  /// Fetches a series' full detail (plot, seasons, episodes) from the provider
  /// on demand and caches it locally. Seasons/episodes are not fetched during
  /// the initial import (too expensive per-series), so this is called when a
  /// series detail screen opens. For sources without a series-info API (M3U)
  /// or when credentials are unavailable, returns an empty [SeriesDetail].
  Future<Result<SeriesDetail>> loadSeriesDetail(Series series);
  Stream<List<Favorite>> favorites(String playlistId);
  Future<void> toggleFavorite(String itemKey, String playlistId, MediaKind kind);

  /// Returns the provider's category list for [playlistId] and [kind].
  ///
  /// For M3U playlists (where no category rows exist) this returns an empty
  /// list — callers should fall back to group-title ids in that case.
  Future<List<CategoryRef>> categories(String playlistId, MediaKind kind);

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
  Future<void> removeProgress(String itemKey);
  Stream<List<WatchProgress>> continueWatching(String playlistId);

  /// Records that [itemKey] (a browsable key — `movie:<id>` / `series:<id>` /
  /// `channel:<id>`) was just opened in the player. Unlike [saveProgress] this
  /// also tracks live channels, and powers the "Recently Viewed" category.
  Future<void> recordView({required String playlistId, required String itemKey});

  /// The browsable keys recently opened in [playlistId], most-recent first.
  /// Consumers filter by key prefix (`movie:`/`series:`/`channel:`).
  Stream<List<String>> recentlyViewed(String playlistId);
}
