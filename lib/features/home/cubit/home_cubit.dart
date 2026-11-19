import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

part 'home_state.dart';

/// Collapses Continue Watching so each series contributes a single card — its
/// most recently watched episode — instead of one card per watched episode.
///
/// [rows] must be ordered newest-first (as [PlaybackRepository.continueWatching]
/// returns them); the first row seen for a given series wins. Movies and other
/// non-series entries are keyed by their own itemKey, so they are never merged.
List<WatchProgress> collapseContinueWatching(List<WatchProgress> rows) {
  final seen = <String>{};
  final result = <WatchProgress>[];
  for (final p in rows) {
    final key = _continueGroupKey(p.itemKey);
    if (seen.add(key)) result.add(p);
  }
  return result;
}

/// Grouping key for [collapseContinueWatching]: the series domain id for
/// episode/series keys (so all episodes of a series share one key), otherwise
/// the itemKey itself.
String _continueGroupKey(String itemKey) {
  if (itemKey.startsWith('episode:')) {
    return itemKey.substring('episode:'.length).split(':season:').first;
  }
  if (itemKey.startsWith('series:')) {
    return itemKey.substring('series:'.length);
  }
  return itemKey;
}

/// Most cards Continue Watching shows.
const int kContinueWatchingLimit = 20;

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._content, this._playback, this._playlists)
    : super(const HomeState());

  final ContentRepository _content;
  final PlaybackRepository _playback;
  final PlaylistRepository _playlists;

  StreamSubscription<Playlist?>? _activeSub;
  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<WatchProgress>>? _continueSub;
  StreamSubscription<List<Favorite>>? _favoritesSub;
  String? _playlistId;
  bool _hasBound = false;

  /// Subscribe to the ACTIVE playlist stream and (re)bind content whenever it
  /// changes — so importing/switching a playlist updates Home live, with no
  /// app restart. (Previously this read `active().first` once and got stuck on
  /// the startup fallback id.)
  Future<void> load() async {
    emit(state.copyWith(loading: true));
    _activeSub = _playlists.active().listen(_onActivePlaylistChanged);
  }

  void _onActivePlaylistChanged(Playlist? playlist) {
    final pid = playlist?.id;
    if (_hasBound && pid == _playlistId) return;
    _hasBound = true;
    _playlistId = pid;

    _moviesSub?.cancel();
    _seriesSub?.cancel();
    _continueSub?.cancel();
    _favoritesSub?.cancel();

    if (pid == null) {
      emit(
        state.copyWith(
          movies: const [],
          series: const [],
          continueWatching: const [],
          favoriteKeys: const {},
          loading: false,
        ),
      );
      return;
    }

    _moviesSub = _content
        .movies(pid)
        .listen(
          (movies) => emit(state.copyWith(movies: movies, loading: false)),
        );
    _seriesSub = _content
        .series(pid)
        .listen((series) => emit(state.copyWith(series: series)));
    _continueSub = _playback
        .progressForPlaylist(pid)
        .listen(_onContinueWatching);
    _favoritesSub = _content
        .favorites(pid)
        .listen(
          (favs) => emit(
            state.copyWith(favoriteKeys: favs.map((f) => f.itemKey).toSet()),
          ),
        );
  }

  /// Bumped per progress emission so a slow [_continueFrom] for an older
  /// emission cannot overwrite a newer one.
  int _continueGeneration = 0;

  /// Builds Continue Watching from every progress row: one card per movie or
  /// series, decided by its newest row. Unfinished: that row. A finished
  /// episode: the next episode, or nothing after the series' last one. A
  /// finished movie: nothing.
  Future<List<WatchProgress>?> _continueFrom(
    List<WatchProgress> rows,
    int generation,
  ) async {
    final newestFirst = rows.where((p) => p.kind != MediaKind.channel).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final cards = <WatchProgress>[];
    for (final p in collapseContinueWatching(newestFirst)) {
      if (cards.length >= kContinueWatchingLimit) break;
      if (!p.isWatched) {
        cards.add(p);
        continue;
      }
      if (!p.itemKey.startsWith('episode:')) continue;
      final next = await _content.episodeAfter(
        p.itemKey.substring('episode:'.length),
      );
      if (isClosed || generation != _continueGeneration) return null;
      if (next == null) continue;
      cards.add(
        WatchProgress(
          itemKey: 'episode:${next.id}',
          playlistId: p.playlistId,
          kind: p.kind,
          positionSec: 0,
          durationSec: 0,
          updatedAt: p.updatedAt,
        ),
      );
    }
    return cards;
  }

  /// Emits Continue Watching, then enriches series-episode entries by fetching
  /// their cached [Episode] rows (for the "S{season} · E{number}" label).
  Future<void> _onContinueWatching(List<WatchProgress> rows) async {
    if (isClosed) return;
    final generation = ++_continueGeneration;
    final cw = await _continueFrom(rows, generation);
    if (cw == null || isClosed) return;
    emit(state.copyWith(continueWatching: cw));

    final episodeIds = [
      for (final p in cw)
        if (p.itemKey.startsWith('episode:'))
          p.itemKey.substring('episode:'.length),
    ];
    if (episodeIds.isEmpty) {
      if (state.episodesById.isNotEmpty) {
        emit(state.copyWith(episodesById: const {}));
      }
      return;
    }
    final eps = await _content.episodesByIds(episodeIds);
    if (isClosed || generation != _continueGeneration) return;
    emit(state.copyWith(episodesById: {for (final e in eps) e.id: e}));
  }

  Future<void> removeFromContinueWatching(String itemKey) async {
    await _playback.removeProgress(itemKey);
  }

  /// Toggles favorite for a movie item.
  /// Keyed as `movie:<id>` with [MediaKind.movie].
  Future<void> toggleFavoriteMovie(VodItem movie) async {
    final pid = _playlistId ?? 'p1';
    await _content.toggleFavorite(
      'movie:${movie.id}',
      pid,
      MediaKind.movie,
      title: movie.title,
    );
  }

  /// Toggles favorite for a series item.
  /// Keyed as `episode:<id>` with [MediaKind.episode] — matching the convention
  /// used in the details screen.
  Future<void> toggleFavoriteSeries(Series series) async {
    final pid = _playlistId ?? 'p1';
    await _content.toggleFavorite(
      'episode:${series.id}',
      pid,
      MediaKind.episode,
      title: series.title,
    );
  }

  @override
  Future<void> close() async {
    await _activeSub?.cancel();
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _continueSub?.cancel();
    await _favoritesSub?.cancel();
    return super.close();
  }
}
