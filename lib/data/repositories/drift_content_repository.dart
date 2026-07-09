import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/result.dart';
import '../credential_store.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../sources/m3u_source.dart';
import '../sources/xtream_source.dart';
import 'repositories.dart';

/// Maps a [MediaKind] to the string type key used in the categories table.
String _kindToType(MediaKind kind) {
  switch (kind) {
    case MediaKind.channel:
      return 'live';
    case MediaKind.movie:
      return 'vod';
    case MediaKind.episode:
      return 'series';
  }
}

/// Drift-backed [ContentRepository].
///
/// [dio], [credentialStore], [m3u], and [xtream] are injectable via constructor
/// so tests can pass fakes without network access.
class DriftContentRepository implements ContentRepository {
  DriftContentRepository(
    this._db, {
    Dio? dio,
    CredentialStore? credentialStore,
    M3uSource? m3u,
    XtreamSource? xtream,
  })  : _dio = dio ?? Dio(),
        _credentials = credentialStore ?? InMemoryCredentialStore(),
        _m3u = m3u ?? M3uSource(),
        _xtream = xtream ?? XtreamSource();

  final AppDatabase _db;
  final Dio _dio;
  final CredentialStore _credentials;
  final M3uSource _m3u;
  final XtreamSource _xtream;

  // ---------------------------------------------------------------------------
  // Row → model helpers
  // ---------------------------------------------------------------------------

  static Channel _channelFromRow(ChannelRow r) => Channel(
        id: r.id,
        playlistId: r.playlistId,
        name: r.name,
        number: r.number,
        logoUrl: r.logoUrl,
        streamUrl: r.streamUrl,
        categoryId: r.categoryId,
      );

  static VodItem _vodFromRow(VodRow r) => VodItem(
        id: r.id,
        playlistId: r.playlistId,
        title: r.title,
        posterUrl: r.posterUrl,
        categoryId: r.categoryId,
        year: r.year,
        rating: r.rating,
        streamUrl: r.streamUrl,
      );

  static Series _seriesFromRow(SeriesRow r) => Series(
        id: r.id,
        playlistId: r.playlistId,
        title: r.title,
        posterUrl: r.posterUrl,
        categoryId: r.categoryId,
        year: r.year,
        rating: r.rating,
      );

  static Season _seasonFromRow(SeasonRow r) =>
      Season(id: r.id, seriesId: r.seriesId, number: r.number);

  static Episode _episodeFromRow(EpisodeRow r) => Episode(
        id: r.id,
        seasonId: r.seasonId,
        title: r.title,
        number: r.number,
        durationSec: r.durationSec,
        streamUrl: r.streamUrl,
      );

  static Favorite _favoriteFromRow(FavoriteRow r) => Favorite(
        itemKey: r.itemKey,
        playlistId: r.playlistId,
        kind: MediaKind.values.byName(r.kind),
        addedAt: r.addedAt,
      );

  // ---------------------------------------------------------------------------
  // Model → companion helpers (for importPlaylist)
  // ---------------------------------------------------------------------------

  static ChannelsCompanion _toChannelCompanion(Channel c) =>
      ChannelsCompanion.insert(
        id: c.id,
        playlistId: c.playlistId,
        name: c.name,
        number: c.number,
        logoUrl: Value(c.logoUrl),
        streamUrl: c.streamUrl,
        categoryId: Value(c.categoryId),
      );

  static VodItemsCompanion _toVodCompanion(VodItem v) =>
      VodItemsCompanion.insert(
        id: v.id,
        playlistId: v.playlistId,
        title: v.title,
        posterUrl: Value(v.posterUrl),
        categoryId: Value(v.categoryId),
        year: Value(v.year),
        rating: Value(v.rating),
        streamUrl: v.streamUrl,
      );

  static SeriesItemsCompanion _toSeriesCompanion(Series s) =>
      SeriesItemsCompanion.insert(
        id: s.id,
        playlistId: s.playlistId,
        title: s.title,
        posterUrl: Value(s.posterUrl),
        categoryId: Value(s.categoryId),
        year: Value(s.year),
        rating: Value(s.rating),
      );

  // ---------------------------------------------------------------------------
  // ContentRepository — streams
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Channel>> channels(String playlistId) =>
      _db.watchChannels(playlistId).map((rows) => rows.map(_channelFromRow).toList());

  @override
  Stream<List<VodItem>> movies(String playlistId) =>
      _db.watchMovies(playlistId).map((rows) => rows.map(_vodFromRow).toList());

  @override
  Stream<List<Series>> series(String playlistId) =>
      _db.watchSeries(playlistId).map((rows) => rows.map(_seriesFromRow).toList());

  // ---------------------------------------------------------------------------
  // ContentRepository — seasons / episodes
  // ---------------------------------------------------------------------------

  @override
  Future<Result<List<Season>>> seasons(String seriesId) async {
    try {
      final rows = await _db.getSeasons(seriesId);
      return Ok(rows.map(_seasonFromRow).toList());
    } catch (e) {
      return Err(Failure('Failed to load seasons', cause: e));
    }
  }

  @override
  Future<Result<List<Episode>>> episodes(String seasonId) async {
    try {
      final rows = await _db.getEpisodes(seasonId);
      return Ok(rows.map(_episodeFromRow).toList());
    } catch (e) {
      return Err(Failure('Failed to load episodes', cause: e));
    }
  }

  @override
  Future<List<Episode>> episodesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _db.getEpisodesByIds(ids);
    return rows.map(_episodeFromRow).toList();
  }

  @override
  Future<Result<SeriesDetail>> loadSeriesDetail(Series series) async {
    debugPrint(
        '[series-detail] load id="${series.id}" pid="${series.playlistId}"');
    try {
      // Locate the playlist (for server URL + type) and its credentials.
      final playlists = await _db.getPlaylists();
      final p =
          playlists.where((r) => r.id == series.playlistId).firstOrNull;
      final serverUrl = p?.serverUrl;
      final creds = await _credentials.read(series.playlistId);
      debugPrint('[series-detail] playlistFound=${p != null} '
          'serverUrl=${serverUrl != null && serverUrl.isNotEmpty} '
          'creds=${creds != null}');

      // Only Xtream exposes a series-info API. Without a server URL or
      // credentials (e.g. M3U), return whatever is cached locally.
      if (serverUrl == null || serverUrl.isEmpty || creds == null) {
        final cached = await _cachedSeriesDetail(series.id);
        debugPrint('[series-detail] no url/creds -> cached '
            'seasons=${cached.seasons.length} '
            'eps=${cached.episodesBySeason.values.fold(0, (a, b) => a + b.length)}');
        return Ok(cached);
      }

      // Raw numeric id is the last segment of '<playlistId>:series:<sid>'.
      final rawId = series.id.split(':series:').last;
      debugPrint('[series-detail] fetching seriesId="$rawId" from $serverUrl');

      final detail = await _xtream.seriesDetail(
        serverUrl: serverUrl,
        username: creds.username,
        password: creds.password,
        seriesId: rawId,
        playlistId: series.playlistId,
      );
      debugPrint('[series-detail] fetched seasons=${detail.seasons.length} '
          'eps=${detail.episodesBySeason.values.fold(0, (a, b) => a + b.length)}');

      // Cache seasons + episodes for offline/repeat views.
      await _db.upsertSeasons([
        for (final s in detail.seasons)
          SeasonsCompanion.insert(
              id: s.id, seriesId: s.seriesId, number: s.number),
      ]);
      for (final entry in detail.episodesBySeason.entries) {
        await _db.upsertEpisodes([
          for (final e in entry.value)
            EpisodesCompanion.insert(
              id: e.id,
              seasonId: e.seasonId,
              title: e.title,
              number: e.number,
              durationSec: Value(e.durationSec),
              streamUrl: e.streamUrl,
            ),
        ]);
      }
      return Ok(detail);
    } catch (e) {
      debugPrint('[series-detail] ERROR: $e');
      // On failure, fall back to any cached detail rather than erroring out.
      try {
        return Ok(await _cachedSeriesDetail(series.id));
      } catch (_) {
        return Err(Failure('Failed to load series detail', cause: e));
      }
    }
  }

  /// Builds a [SeriesDetail] from locally cached season/episode rows.
  Future<SeriesDetail> _cachedSeriesDetail(String seriesDomainId) async {
    final seasonRows = await _db.getSeasons(seriesDomainId);
    final seasons = seasonRows.map(_seasonFromRow).toList();
    final bySeason = <String, List<Episode>>{};
    for (final s in seasons) {
      final eps = await _db.getEpisodes(s.id);
      bySeason[s.id] = eps.map(_episodeFromRow).toList();
    }
    return SeriesDetail(seasons: seasons, episodesBySeason: bySeason);
  }

  // ---------------------------------------------------------------------------
  // ContentRepository — favorites
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Favorite>> favorites(String playlistId) =>
      _db.watchFavorites(playlistId).map((rows) => rows.map(_favoriteFromRow).toList());

  @override
  Future<void> toggleFavorite(
      String itemKey, String playlistId, MediaKind kind) async {
    final exists = await _db.isFavorite(itemKey);
    if (exists) {
      await _db.removeFavorite(itemKey);
    } else {
      await _db.addFavorite(
        FavoritesCompanion.insert(
          itemKey: itemKey,
          playlistId: playlistId,
          kind: kind.name,
          addedAt: DateTime.now(),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ContentRepository — categories
  // ---------------------------------------------------------------------------

  @override
  Future<List<CategoryRef>> categories(String playlistId, MediaKind kind) async {
    final type = _kindToType(kind);
    final rows = await _db.getCategories(playlistId, type);
    return rows.map((r) => CategoryRef(id: r.categoryId, name: r.name)).toList();
  }

  // ---------------------------------------------------------------------------
  // ContentRepository — importPlaylist
  // ---------------------------------------------------------------------------

  @override
  Future<Result<void>> importPlaylist(Playlist p) async {
    try {
      switch (p.type) {
        case PlaylistType.m3u:
          final url = p.serverUrl;
          if (url == null || url.isEmpty) {
            return const Err(Failure('M3U playlist has no server URL'));
          }
          final response = await _dio.get<String>(url);
          final body = response.data ?? '';
          final channels = await _m3u.parse(body, playlistId: p.id);
          await _db.replaceChannels(
              p.id, channels.map(_toChannelCompanion).toList());

        case PlaylistType.xtream:
          final serverUrl = p.serverUrl;
          if (serverUrl == null || serverUrl.isEmpty) {
            return const Err(Failure('Xtream playlist has no server URL'));
          }
          final creds = await _credentials.read(p.id);
          if (creds == null) {
            return const Err(Failure('Xtream credentials missing'));
          }
          final content = await _xtream.fetchAll(
            serverUrl: serverUrl,
            username: creds.username,
            password: creds.password,
            playlistId: p.id,
          );

          // Group categories by type and persist each group.
          final catsByType = <String, List<CategoriesCompanion>>{};
          for (final cat in content.categories) {
            catsByType.putIfAbsent(cat.type, () => []).add(
              CategoriesCompanion.insert(
                playlistId: p.id,
                type: cat.type,
                categoryId: cat.id,
                name: cat.name,
              ),
            );
          }

          await Future.wait([
            _db.replaceChannels(
                p.id, content.channels.map(_toChannelCompanion).toList()),
            _db.replaceMovies(
                p.id, content.movies.map(_toVodCompanion).toList()),
            _db.replaceSeries(
                p.id, content.series.map(_toSeriesCompanion).toList()),
            for (final entry in catsByType.entries)
              _db.replaceCategories(p.id, entry.key, entry.value),
          ]);

        case PlaylistType.upload:
          // Upload type: content is assumed already in the local store.
          return const Ok(null);
      }
      return const Ok(null);
    } catch (e) {
      return Err(Failure('Failed to import playlist', cause: e));
    }
  }
}
