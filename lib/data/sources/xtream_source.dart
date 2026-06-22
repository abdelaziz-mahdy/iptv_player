import 'package:noor_iptv/data/models/models.dart' as noor;
import 'package:xtream_code_client/xtream_code_client.dart'
    as xc
    show
        XtreamClient,
        LiveStreamItem,
        VodItem,
        SeriesItem;

/// Holds the three content types fetched from an Xtream Codes server in a
/// single [XtreamSource.fetchAll] call.
class XtreamContent {
  const XtreamContent({
    required this.channels,
    required this.movies,
    required this.series,
  });

  final List<noor.Channel> channels;
  final List<noor.VodItem> movies;
  final List<noor.Series> series;
}

// ---------------------------------------------------------------------------
// Pure mapping helpers (top-level so they are directly unit-testable without
// any network interaction).
// ---------------------------------------------------------------------------

/// Maps a [xc.LiveStreamItem] to a NOOR [noor.Channel].
///
/// The stream URL is built following the Xtream Codes convention:
///   `{serverUrl}/{username}/{password}/{streamId}.ts`
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
  return '$base/$username/$password/$streamId.$ext';
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
      ]);

      final liveItems = results[0] as List<xc.LiveStreamItem>;
      final vodItems = results[1] as List<xc.VodItem>;
      final seriesItems = results[2] as List<xc.SeriesItem>;

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

      return XtreamContent(channels: channels, movies: movies, series: series);
    } finally {
      // Only close clients we created; injected clients are managed externally.
      if (_overrideClient == null) client.close();
    }
  }
}
