import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/result.dart';
import '../../core/secure_storage.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../sources/m3u_source.dart';
import '../sources/xtream_source.dart';
import 'repositories.dart';

/// Drift-backed [ContentRepository].
///
/// [dio], [secureStorage], [m3u], and [xtream] are injectable via constructor
/// so tests can pass fakes without network access.
class DriftContentRepository implements ContentRepository {
  DriftContentRepository(
    this._db, {
    Dio? dio,
    FlutterSecureStorage? secureStorage,
    M3uSource? m3u,
    XtreamSource? xtream,
  })  : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? appSecureStorage,
        _m3u = m3u ?? M3uSource(),
        _xtream = xtream ?? XtreamSource();

  final AppDatabase _db;
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
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
          final username =
              await _secureStorage.read(key: 'xtream_user_${p.id}') ?? '';
          final password =
              await _secureStorage.read(key: 'xtream_pass_${p.id}') ?? '';
          final content = await _xtream.fetchAll(
            serverUrl: serverUrl,
            username: username,
            password: password,
            playlistId: p.id,
          );
          await Future.wait([
            _db.replaceChannels(
                p.id, content.channels.map(_toChannelCompanion).toList()),
            _db.replaceMovies(
                p.id, content.movies.map(_toVodCompanion).toList()),
            _db.replaceSeries(
                p.id, content.series.map(_toSeriesCompanion).toList()),
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
