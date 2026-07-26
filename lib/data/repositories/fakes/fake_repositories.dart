import 'dart:async';

import '../../../core/result.dart';
import '../../models/models.dart';
import '../repositories.dart';

/// A tiny reactive value holder: its [stream] replays the current value to
/// every new listener, then forwards subsequent updates. Used so fakes behave
/// like a live local store (drift `.watch()`) for UI and tests.
class _Store<T> {
  T _value;
  final _ctrl = StreamController<T>.broadcast();
  _Store(this._value);

  T get value => _value;
  set value(T v) {
    _value = v;
    _ctrl.add(v);
  }

  Stream<T> get stream async* {
    yield _value;
    yield* _ctrl.stream;
  }
}

const _seedPlaylistId = 'p1';

Playlist _seedPlaylist() => const Playlist(
      id: _seedPlaylistId,
      name: 'My Playlist',
      type: PlaylistType.m3u,
      serverUrl: null,
      initial: 'M',
      channelCount: 3,
    );

/// In-memory [PlaylistRepository] seeded with one playlist.
class FakePlaylistRepository implements PlaylistRepository {
  final _playlists = _Store<List<Playlist>>([_seedPlaylist()]);
  final _active = _Store<Playlist?>(_seedPlaylist());

  @override
  Future<Result<List<Playlist>>> all() async => Ok(_playlists.value);

  @override
  Future<Result<Playlist>> add(Playlist p) async {
    _playlists.value = [..._playlists.value, p];
    return Ok(p);
  }

  @override
  Future<Result<void>> remove(String id) async {
    _playlists.value = _playlists.value.where((p) => p.id != id).toList();
    return const Ok(null);
  }

  @override
  Stream<Playlist?> active() => _active.stream;

  @override
  Future<void> setActive(String id) async {
    _active.value = _playlists.value.where((p) => p.id == id).firstOrNull;
  }
}

/// In-memory [ContentRepository] seeded with sample channels, movies, and
/// series so feature screens can be developed before the real data layer.
class FakeContentRepository implements ContentRepository {
  final _channels = _Store<List<Channel>>([
    const Channel(id: 'c1', playlistId: _seedPlaylistId, name: 'NOOR One', number: '101', streamUrl: 'http://x/1'),
    const Channel(id: 'c2', playlistId: _seedPlaylistId, name: 'NOOR Sports', number: '102', streamUrl: 'http://x/2'),
    const Channel(id: 'c3', playlistId: _seedPlaylistId, name: 'NOOR News', number: '103', streamUrl: 'http://x/3'),
  ]);
  final _movies = _Store<List<VodItem>>([
    const VodItem(id: 'm1', playlistId: _seedPlaylistId, title: 'The Signal', year: '2024', streamUrl: 'http://x/m1'),
    const VodItem(id: 'm2', playlistId: _seedPlaylistId, title: 'Dune', year: '2021', streamUrl: 'http://x/m2'),
    const VodItem(id: 'm3', playlistId: _seedPlaylistId, title: 'Arrival', year: '2016', streamUrl: 'http://x/m3'),
    const VodItem(id: 'm4', playlistId: _seedPlaylistId, title: 'Interstellar', year: '2014', streamUrl: 'http://x/m4'),
  ]);
  final _series = _Store<List<Series>>([
    const Series(id: 's1', playlistId: _seedPlaylistId, title: 'Deep Field', year: '2025'),
    const Series(id: 's2', playlistId: _seedPlaylistId, title: 'Horizon', year: '2023'),
  ]);
  final _favorites = _Store<List<Favorite>>([]);

  static const _seasons = {
    's1': [Season(id: 's1-1', seriesId: 's1', number: 1)],
    's2': [Season(id: 's2-1', seriesId: 's2', number: 1)],
    // Two seasons: exercises play/queue behaviour across a season boundary.
    's3': [
      Season(id: 's3-1', seriesId: 's3', number: 1),
      Season(id: 's3-2', seriesId: 's3', number: 2),
    ],
  };
  static const _episodes = {
    's1-1': [
      Episode(id: 's1-1-e1', seasonId: 's1-1', title: 'Pilot', number: 1, durationSec: 2700, streamUrl: 'http://x/e1'),
      Episode(id: 's1-1-e2', seasonId: 's1-1', title: 'Contact', number: 2, durationSec: 2700, streamUrl: 'http://x/e2'),
    ],
    's2-1': [
      Episode(id: 's2-1-e1', seasonId: 's2-1', title: 'Dawn', number: 1, durationSec: 2700, streamUrl: 'http://x/e3'),
    ],
    's3-1': [
      Episode(id: 's3-1-e1', seasonId: 's3-1', title: 'S1E1', number: 1, durationSec: 2700, streamUrl: 'http://x/s3e1'),
      Episode(id: 's3-1-e2', seasonId: 's3-1', title: 'S1E2', number: 2, durationSec: 2700, streamUrl: 'http://x/s3e2'),
    ],
    's3-2': [
      Episode(id: 's3-2-e1', seasonId: 's3-2', title: 'S2E1', number: 1, durationSec: 2700, streamUrl: 'http://x/s3e3'),
      Episode(id: 's3-2-e2', seasonId: 's3-2', title: 'S2E2', number: 2, durationSec: 2700, streamUrl: 'http://x/s3e4'),
    ],
  };

  @override
  Stream<List<Channel>> channels(String playlistId) => _channels.stream;

  @override
  Stream<List<VodItem>> movies(String playlistId) => _movies.stream;

  @override
  Stream<List<Series>> series(String playlistId) => _series.stream;

  @override
  Future<Result<List<Season>>> seasons(String seriesId) async =>
      Ok(_seasons[seriesId] ?? const []);

  @override
  Future<Result<List<Episode>>> episodes(String seasonId) async =>
      Ok(_episodes[seasonId] ?? const []);

  @override
  Future<List<Episode>> episodesByIds(List<String> ids) async {
    final idSet = ids.toSet();
    return [
      for (final list in _episodes.values)
        for (final e in list)
          if (idSet.contains(e.id)) e,
    ];
  }

  @override
  Future<Result<SeriesDetail>> loadSeriesDetail(Series series) async {
    final seasons = _seasons[series.id] ?? const <Season>[];
    final bySeason = {
      for (final s in seasons) s.id: _episodes[s.id] ?? const <Episode>[],
    };
    return Ok(SeriesDetail(
      info: MediaDetail(
        description: 'A gripping ${series.title} story.',
        cast: 'Ada Lovelace, Alan Turing',
        genre: 'Drama',
        rating: 8.4,
      ),
      seasons: seasons,
      episodesBySeason: bySeason,
    ));
  }

  @override
  Future<Result<MediaDetail>> loadMovieDetail(VodItem movie) async => Ok(
        MediaDetail(
          description: 'A gripping ${movie.title} story.',
          cast: 'Ada Lovelace, Alan Turing',
          director: 'Grace Hopper',
          genre: 'Drama',
          country: 'US',
          rating: 7.9,
          durationSec: 5400,
        ),
      );

  @override
  Stream<List<Favorite>> favorites(String playlistId) => _favorites.stream;

  @override
  Future<void> toggleFavorite(String itemKey, String playlistId, MediaKind kind,
      {String title = ''}) async {
    final existing = _favorites.value.where((f) => f.itemKey == itemKey).toList();
    if (existing.isEmpty) {
      _favorites.value = [
        ..._favorites.value,
        Favorite(
            itemKey: itemKey,
            playlistId: playlistId,
            kind: kind,
            addedAt: DateTime.utc(2026),
            title: title),
      ];
    } else {
      _favorites.value = _favorites.value.where((f) => f.itemKey != itemKey).toList();
    }
  }

  @override
  Future<void> repairFavorite(
      {required String oldItemKey,
      required String newItemKey,
      required String title}) async {
    final old = _favorites.value
        .cast<Favorite?>()
        .firstWhere((f) => f?.itemKey == oldItemKey, orElse: () => null);
    if (old == null) return;
    _favorites.value = [
      for (final f in _favorites.value)
        if (f.itemKey != oldItemKey && f.itemKey != newItemKey) f,
      old.copyWith(itemKey: newItemKey, title: title),
    ];
  }

  @override
  Future<List<CategoryRef>> categories(String playlistId, MediaKind kind) async {
    return switch (kind) {
      MediaKind.movie => const [
          CategoryRef(id: 'cat1', name: 'Action'),
          CategoryRef(id: 'cat2', name: 'Drama'),
        ],
      MediaKind.channel => const [
          CategoryRef(id: 'cat3', name: 'Sports'),
          CategoryRef(id: 'cat4', name: 'News'),
        ],
      MediaKind.episode => const [
          CategoryRef(id: 'cat5', name: 'Sci-Fi'),
        ],
    };
  }

  @override
  Future<void> recordCategoryUse(
      String playlistId, MediaKind kind, String categoryId) async {
    final used = _categoryUse.putIfAbsent(kind, () => <String>[])
      ..remove(categoryId)
      ..insert(0, categoryId);
    _recentCategories
        .putIfAbsent(kind, () => _Store<List<String>>([]))
        .value = List<String>.from(used);
  }

  @override
  Stream<List<String>> recentCategoryIds(String playlistId, MediaKind kind) =>
      _recentCategories
          .putIfAbsent(kind, () => _Store<List<String>>([]))
          .stream;

  final _categoryUse = <MediaKind, List<String>>{};
  final _recentCategories = <MediaKind, _Store<List<String>>>{};

  @override
  Future<Result<void>> importPlaylist(Playlist p) async => const Ok(null);
}

/// In-memory [EpgRepository] returning two sample programmes per channel.
class FakeEpgRepository implements EpgRepository {
  @override
  Future<Result<List<EpgProgramme>>> programmes(
      String channelId, DateTime from, DateTime to) async {
    return Ok([
      EpgProgramme(
          id: '$channelId-1', channelId: channelId, title: 'On Now',
          startUtc: from, stopUtc: from.add(const Duration(hours: 1))),
      EpgProgramme(
          id: '$channelId-2', channelId: channelId, title: 'Up Next',
          startUtc: from.add(const Duration(hours: 1)), stopUtc: from.add(const Duration(hours: 2))),
    ]);
  }
}

/// In-memory [PlaybackRepository] with no seeded progress.
class FakePlaybackRepository implements PlaybackRepository {
  final _progress = <String, WatchProgress>{};
  final _continue = _Store<List<WatchProgress>>([]);
  final _all = _Store<List<WatchProgress>>([]);

  /// Recently-viewed browsable keys, most-recent first.
  final _recentKeys = <String>[];
  final _recents = _Store<List<String>>([]);

  List<WatchProgress> _filtered() {
    final all = _progress.values
        .where((p) => p.kind != MediaKind.channel && !p.isWatched)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all.take(20).toList();
  }

  @override
  Future<WatchProgress?> progressFor(String itemKey) async => _progress[itemKey];

  @override
  Future<void> saveProgress(WatchProgress p) async {
    _progress[p.itemKey] = p;
    _continue.value = _filtered();
    _all.value = _progress.values.toList();
  }

  @override
  Future<void> removeProgress(String itemKey) async {
    _progress.remove(itemKey);
    _continue.value = _filtered();
    _all.value = _progress.values.toList();
  }

  @override
  Stream<List<WatchProgress>> continueWatching(String playlistId) => _continue.stream;

  @override
  Stream<List<WatchProgress>> progressForPlaylist(String playlistId) => _all.stream;

  @override
  Future<void> recordView({
    required String playlistId,
    required String itemKey,
  }) async {
    _recentKeys
      ..remove(itemKey)
      ..insert(0, itemKey);
    _recents.value = List<String>.from(_recentKeys);
  }

  @override
  Stream<List<String>> recentlyViewed(
    String playlistId, {
    required String prefix,
    int limit = kRecentlyViewedLimit,
  }) =>
      _recents.stream.map((keys) =>
          keys.where((k) => k.startsWith(prefix)).take(limit).toList());
}
