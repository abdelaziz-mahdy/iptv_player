import 'package:iptv_player/data/models/models.dart' as noor;
import 'package:xtream_code_client/xtream_code_client.dart'
    as xc
    show
        XtreamClient,
        Category,
        LiveStreamItem,
        VodItem,
        SeriesItem,
        Season,
        Episode;

/// Holds the three content types fetched from an Xtream Codes server in a
/// single [XtreamSource.fetchAll] call.
class XtreamContent {
  const XtreamContent({
    required this.channels,
    required this.movies,
    required this.series,
    this.categories = const [],
  });

  final List<noor.Channel> channels;
  final List<noor.VodItem> movies;
  final List<noor.Series> series;

  /// Flat list of all categories across all types: live, vod, series.
  ///
  /// Each entry is a record with `type` (e.g. `'live'`), `id` (the numeric
  /// category id as a string), and `name` (the human-readable label).
  final List<({String type, String id, String name})> categories;
}

// ---------------------------------------------------------------------------
// Pure mapping helpers (top-level so they are directly unit-testable without
// any network interaction).
// ---------------------------------------------------------------------------

/// Maps a [xc.LiveStreamItem] to a NOOR [noor.Channel].
///
/// The stream URL is built following the Xtream Codes convention:
///   `{serverUrl}/live/{username}/{password}/{streamId}.ts`
///
/// [index] is used as the channel number fallback when [item.num] is null.
noor.Channel channelFromLive(
  xc.LiveStreamItem item, {
  required String playlistId,
  required String serverUrl,
  required String username,
  required String password,
  required int index,
}) {
  final streamId = item.streamId ?? 0;
  final streamUrl = _buildLiveUrl(
    serverUrl: serverUrl,
    username: username,
    password: password,
    streamId: streamId,
  );

  return noor.Channel(
    id: '$playlistId:live:$streamId',
    playlistId: playlistId,
    name: item.name ?? '',
    number: item.num != null ? '${item.num}' : '${index + 1}',
    logoUrl: item.streamIcon?.isEmpty ?? true ? null : item.streamIcon,
    streamUrl: streamUrl,
    categoryId:
        item.categoryId != null ? '${item.categoryId}' : null,
  );
}

/// Maps a [xc.VodItem] to a NOOR [noor.VodItem].
///
/// The movie URL is built as:
///   `{serverUrl}/movie/{username}/{password}/{streamId}.{ext}`
///
/// Uses `containerExtension` from the item when present; falls back to `mp4`.
noor.VodItem vodItemFromXtream(
  xc.VodItem item, {
  required String playlistId,
  required String serverUrl,
  required String username,
  required String password,
}) {
  final streamId = item.streamId ?? 0;
  final ext = (item.containerExtension?.isNotEmpty ?? false)
      ? item.containerExtension!
      : 'mp4';

  final streamUrl = _buildMovieUrl(
    serverUrl: serverUrl,
    username: username,
    password: password,
    streamId: streamId,
    ext: ext,
  );

  return noor.VodItem(
    id: '$playlistId:vod:$streamId',
    playlistId: playlistId,
    title: item.title ?? item.name ?? '',
    posterUrl: item.streamIcon?.isEmpty ?? true ? null : item.streamIcon,
    categoryId:
        item.categoryId != null ? '${item.categoryId}' : null,
    year: item.year?.isEmpty ?? true ? null : item.year,
    rating: _safeRating(item.rating),
    streamUrl: streamUrl,
  );
}

/// Maps a [xc.SeriesItem] to a NOOR [noor.Series].
///
/// Series have no direct playback URL at the list level; episodes are fetched
/// on demand via [XtreamClient.seriesInfoData].
noor.Series seriesFromXtream(
  xc.SeriesItem item, {
  required String playlistId,
}) {
  return noor.Series(
    id: '$playlistId:series:${item.seriesId ?? 0}',
    playlistId: playlistId,
    title: item.title ?? item.name ?? '',
    posterUrl: item.cover?.isEmpty ?? true ? null : item.cover,
    categoryId:
        item.categoryId != null ? '${item.categoryId}' : null,
    year: item.year?.isEmpty ?? true ? null : item.year,
    rating: _safeRating(item.rating),
  );
}

/// Maps a [xc.Season] to a NOOR [noor.Season].
///
/// The domain season id is `'<playlistId>:series:<numericSeriesId>:season:<seasonNum>'`.
/// [seriesId] is the raw numeric id string extracted from the domain series id.
noor.Season seasonFromXtreamSeason(
  xc.Season xcSeason, {
  required String seriesId,
  required String playlistId,
}) {
  final num = xcSeason.seasonNumber ?? 1;
  final domainSeriesId = '$playlistId:series:$seriesId';
  return noor.Season(
    id: '$domainSeriesId:season:$num',
    seriesId: domainSeriesId,
    number: num,
  );
}

/// Maps a [xc.Episode] to a NOOR [noor.Episode].
///
/// Episode stream URL convention:
///   `{serverUrl}/series/{username}/{password}/{id}.{ext}`
noor.Episode episodeFromXtreamEpisode(
  xc.Episode xcEp, {
  required String seasonId,
  required String serverUrl,
  required String username,
  required String password,
}) {
  final epId = xcEp.id ?? 0;
  final ext = (xcEp.containerExtension?.isNotEmpty ?? false)
      ? xcEp.containerExtension!
      : 'mp4';
  final streamUrl = _buildSeriesUrl(
    serverUrl: serverUrl,
    username: username,
    password: password,
    episodeId: epId,
    ext: ext,
  );
  return noor.Episode(
    id: '$seasonId:ep:$epId',
    seasonId: seasonId,
    title: xcEp.title ?? '',
    number: xcEp.episodeNum ?? 0,
    durationSec: xcEp.info.durationSecs,
    streamUrl: streamUrl,
  );
}

/// Assembles a [noor.SeriesDetail] from the raw pieces of an Xtream
/// series-info payload.
///
/// Season numbers can come from the `seasons` array, the `episodes` map keys,
/// or both. Many Xtream providers omit `seasons` entirely and only return
/// episodes keyed by season number — so union both sources instead of
/// iterating `seasons` alone (which would drop every episode).
///
/// Seasons with no episodes are dropped: some providers advertise related
/// shows as extra entries in the `seasons` metadata array without shipping
/// any episodes for them, and an episode-less season has nothing to play.
noor.SeriesDetail seriesDetailFromXtreamInfo({
  required List<xc.Season> xcSeasons,
  required Map<String, List<xc.Episode>> xcEpisodeMap,
  String? description,
  required String seriesId,
  required String playlistId,
  required String serverUrl,
  required String username,
  required String password,
}) {
  final domainSeriesId = '$playlistId:series:$seriesId';
  final seasonNumbers = <int>{
    for (final s in xcSeasons) s.seasonNumber ?? 1,
    for (final k in xcEpisodeMap.keys) int.tryParse(k) ?? 1,
  }.toList()
    ..sort();

  final domainSeasons = <noor.Season>[];
  final episodesBySeason = <String, List<noor.Episode>>{};
  for (final num in seasonNumbers) {
    final xcEps = xcEpisodeMap[num.toString()] ?? const [];
    if (xcEps.isEmpty) continue;
    final season = noor.Season(
      id: '$domainSeriesId:season:$num',
      seriesId: domainSeriesId,
      number: num,
    );
    domainSeasons.add(season);
    episodesBySeason[season.id] = xcEps
        .map((e) => episodeFromXtreamEpisode(
              e,
              seasonId: season.id,
              serverUrl: serverUrl,
              username: username,
              password: password,
            ))
        .toList();
  }

  return noor.SeriesDetail(
    description: description?.isNotEmpty == true ? description : null,
    seasons: domainSeasons,
    episodesBySeason: episodesBySeason,
  );
}

// ---------------------------------------------------------------------------
// Private URL builders
// ---------------------------------------------------------------------------

String _normalizeServerUrl(String serverUrl) {
  var url = serverUrl.trim();
  if (url.endsWith('/')) url = url.substring(0, url.length - 1);
  return url;
}

String _buildLiveUrl({
  required String serverUrl,
  required String username,
  required String password,
  required int streamId,
  String ext = 'ts',
}) {
  final base = _normalizeServerUrl(serverUrl);
  return '$base/live/$username/$password/$streamId.$ext';
}

String _buildMovieUrl({
  required String serverUrl,
  required String username,
  required String password,
  required int streamId,
  required String ext,
}) {
  final base = _normalizeServerUrl(serverUrl);
  return '$base/movie/$username/$password/$streamId.$ext';
}

String _buildSeriesUrl({
  required String serverUrl,
  required String username,
  required String password,
  required int episodeId,
  required String ext,
}) {
  final base = _normalizeServerUrl(serverUrl);
  return '$base/series/$username/$password/$episodeId.$ext';
}

/// Safely converts a [dynamic] rating value to [double?].
///
/// Returns `null` for `null`, empty string, or any non-parseable value so
/// that garbage data from a server never throws.
double? _safeRating(dynamic raw) {
  if (raw == null) return null;
  if (raw is double) return raw;
  if (raw is int) return raw.toDouble();
  if (raw is String) {
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }
  return null;
}

// ---------------------------------------------------------------------------
// XtreamSource — the public adapter
// ---------------------------------------------------------------------------

/// Connects to an Xtream Codes server and fetches live channels, VOD movies,
/// and series (list only — seasons/episodes are fetched on demand elsewhere).
///
/// Inject a custom [XtreamClient] via [XtreamSource.withClient] in tests
/// to avoid real network calls.
class XtreamSource {
  XtreamSource() : _overrideClient = null;

  /// Constructor that accepts a pre-built client for testing.
  XtreamSource.withClient(xc.XtreamClient client) : _overrideClient = client;

  final xc.XtreamClient? _overrideClient;

  /// Connects to [serverUrl] with [username]/[password] and fetches all three
  /// content types in parallel, mapping them to NOOR domain models.
  Future<XtreamContent> fetchAll({
    required String serverUrl,
    required String username,
    required String password,
    required String playlistId,
  }) async {
    final client = _overrideClient ??
        xc.XtreamClient(
          url: serverUrl,
          username: username,
          password: password,
        );

    try {
      final results = await Future.wait([
        client.liveStreamItemsData(),
        client.vodItemsData(),
        client.seriesItemsData(),
        client.liveStreamCategoriesData(),
        client.vodCategoriesData(),
        client.seriesCategoriesData(),
      ]);

      final liveItems = results[0] as List<xc.LiveStreamItem>;
      final vodItems = results[1] as List<xc.VodItem>;
      final seriesItems = results[2] as List<xc.SeriesItem>;
      final liveCategories = results[3] as List<xc.Category>;
      final vodCategories = results[4] as List<xc.Category>;
      final seriesCategories = results[5] as List<xc.Category>;

      final channels = [
        for (var i = 0; i < liveItems.length; i++)
          channelFromLive(
            liveItems[i],
            playlistId: playlistId,
            serverUrl: serverUrl,
            username: username,
            password: password,
            index: i,
          ),
      ];

      final movies = [
        for (final item in vodItems)
          vodItemFromXtream(
            item,
            playlistId: playlistId,
            serverUrl: serverUrl,
            username: username,
            password: password,
          ),
      ];

      final series = [
        for (final item in seriesItems) seriesFromXtream(item, playlistId: playlistId),
      ];

      final categories = [
        for (final c in liveCategories)
          if (c.categoryId != null && c.categoryName != null)
            (type: 'live', id: '${c.categoryId}', name: c.categoryName!),
        for (final c in vodCategories)
          if (c.categoryId != null && c.categoryName != null)
            (type: 'vod', id: '${c.categoryId}', name: c.categoryName!),
        for (final c in seriesCategories)
          if (c.categoryId != null && c.categoryName != null)
            (type: 'series', id: '${c.categoryId}', name: c.categoryName!),
      ];

      return XtreamContent(channels: channels, movies: movies, series: series, categories: categories);
    } finally {
      // Only close clients we created; injected clients are managed externally.
      if (_overrideClient == null) client.close();
    }
  }

  /// Fetches the plot/description for a single VOD item.
  ///
  /// [vodStreamId] is the numeric stream id extracted from the domain movie id
  /// (i.e. the last segment of `'<playlistId>:vod:<streamId>'`).
  ///
  /// Returns `null` when the server returns no plot and no description.
  Future<String?> vodPlot({
    required String serverUrl,
    required String username,
    required String password,
    required String vodStreamId,
  }) async {
    final client = _overrideClient ??
        xc.XtreamClient(
          url: serverUrl,
          username: username,
          password: password,
        );
    try {
      final info = await client.vodInfoData(
        xc.VodItem(streamId: int.parse(vodStreamId)),
      );
      return info.info.plot?.isNotEmpty == true
          ? info.info.plot
          : info.info.description;
    } finally {
      if (_overrideClient == null) client.close();
    }
  }

  /// Fetches the full detail payload for a series: description, seasons,
  /// and all episodes grouped by season domain id.
  ///
  /// [seriesId] is the raw numeric id string (last segment of the domain id).
  /// [playlistId] is used to construct domain ids for seasons and episodes.
  Future<noor.SeriesDetail> seriesDetail({
    required String serverUrl,
    required String username,
    required String password,
    required String seriesId,
    required String playlistId,
  }) async {
    final client = _overrideClient ??
        xc.XtreamClient(
          url: serverUrl,
          username: username,
          password: password,
        );
    try {
      final info = await client.seriesInfoData(
        xc.SeriesItem(seriesId: int.parse(seriesId)),
      );

      return seriesDetailFromXtreamInfo(
        xcSeasons: info.seasons ?? const [],
        xcEpisodeMap: info.episodes ?? const {},
        description: info.info.plot,
        seriesId: seriesId,
        playlistId: playlistId,
        serverUrl: serverUrl,
        username: username,
        password: password,
      );
    } finally {
      if (_overrideClient == null) client.close();
    }
  }
}
