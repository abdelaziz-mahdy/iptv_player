import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../grid/cubit/grid_cubit.dart' show GridEntry;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class FavoritesState extends Equatable {
  final bool loading;

  /// Newest favorite first.
  final List<GridEntry> entries;

  /// Watch progress of favorite movies, keyed by entry id. Series have no
  /// single position and channels are live, so neither has an entry.
  final Map<String, WatchProgress> movieProgress;

  const FavoritesState({
    this.loading = false,
    this.entries = const [],
    this.movieProgress = const {},
  });

  bool get isEmpty => entries.isEmpty;

  WatchProgress? progressFor(GridEntry entry) => movieProgress[entry.id];

  FavoritesState copyWith({
    bool? loading,
    List<GridEntry>? entries,
    Map<String, WatchProgress>? movieProgress,
  }) {
    return FavoritesState(
      loading: loading ?? this.loading,
      entries: entries ?? this.entries,
      movieProgress: movieProgress ?? this.movieProgress,
    );
  }

  @override
  List<Object?> get props => [loading, entries, movieProgress];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(this._content, this._playlists, {this._playback})
      : super(const FavoritesState());

  final ContentRepository _content;
  final PlaylistRepository _playlists;

  /// Optional: powers the watched/progress look on favorite movies.
  final PlaybackRepository? _playback;
  StreamSubscription<List<WatchProgress>>? _progressSub;
  Map<String, WatchProgress> _progress = const {};

  StreamSubscription<Playlist?>? _activeSub;
  StreamSubscription<List<Favorite>>? _favsSub;
  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<Channel>>? _channelsSub;
  String? _playlistId;
  bool _hasBound = false;

  // latest snapshots
  List<Favorite> _favorites = [];
  List<VodItem> _movies = [];
  List<Series> _series = [];
  List<Channel> _channels = [];

  /// Catalogs (movies/series/channels) that have emitted since binding. A
  /// favorite only counts as unresolvable once all three are in: on the TV
  /// every favorite was logged "hidden" because favorites arrived first.
  final Set<MediaKind> _loaded = {};

  /// React to the ACTIVE playlist so favorites reflect the imported/switched
  /// playlist live, without an app restart.
  Future<void> load() async {
    emit(state.copyWith(loading: true));
    _activeSub = _playlists.active().listen(_onActivePlaylistChanged);
  }

  void _onActivePlaylistChanged(Playlist? playlist) {
    final pid = playlist?.id;
    if (_hasBound && pid == _playlistId) return;
    _hasBound = true;
    _playlistId = pid;

    _favsSub?.cancel();
    _moviesSub?.cancel();
    _seriesSub?.cancel();
    _channelsSub?.cancel();
    _progressSub?.cancel();
    _progress = const {};
    _favorites = [];
    _movies = [];
    _series = [];
    _channels = [];
    _loaded.clear();

    if (pid == null) {
      emit(state.copyWith(loading: false, entries: const []));
      return;
    }

    _favsSub = _content.favorites(pid).listen((favs) {
      _favorites = favs;
      _rebuild();
    });

    _moviesSub = _content.movies(pid).listen((movies) {
      _movies = movies;
      _loaded.add(MediaKind.movie);
      _rebuild();
    });

    _seriesSub = _content.series(pid).listen((series) {
      _series = series;
      _loaded.add(MediaKind.episode);
      _rebuild();
    });

    _channelsSub = _content.channels(pid).listen((channels) {
      _channels = channels;
      _loaded.add(MediaKind.channel);
      _rebuild();
    });

    _progressSub = _playback?.progressForPlaylist(pid).listen((rows) {
      _progress = {for (final r in rows) r.itemKey: r};
      _rebuild();
    });
  }

  /// Unresolvable favorites already logged this session (avoid re-logging on
  /// every stream emission).
  final Set<String> _loggedMissing = {};

  void _rebuild() {
    final entries = <GridEntry>[];
    final movieProgress = <String, WatchProgress>{};
    final newestFirst = [..._favorites]
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    for (final fav in newestFirst) {
      final entry = _resolve(fav);
      if (entry != null) {
        entries.add(entry);
        if (fav.kind == MediaKind.movie) {
          final p = _progress['movie:${entry.id}'];
          if (p != null) movieProgress[entry.id] = p;
        }
      } else if (_loaded.length == 3 && _loggedMissing.add(fav.itemKey)) {
        appLog.warning(
            'favorites: ${fav.itemKey} title="${fav.title}" unresolvable — hidden');
      }
    }
    emit(state.copyWith(
        loading: false, entries: entries, movieProgress: movieProgress));
  }

  /// Finds the favorited item among [items].
  ///
  /// Provider stream ids (embedded in the favorite's key) are NOT stable
  /// across re-imports — providers renumber and reuse them — so a bare id
  /// match can silently point at the wrong content. The stored title snapshot
  /// disambiguates:
  ///  - id matches and title agrees (or legacy row without one) → trust it;
  ///  - id matches but the title now belongs to a different item → the id was
  ///    reassigned; follow the title and rewrite the favorite's key;
  ///  - id gone → find by title and rewrite the key;
  ///  - id matches, title differs, and no item carries the stored title → the
  ///    provider renamed it; keep the id and adopt the new title.
  /// Rewrites are fire-and-forget: the favorites stream re-emits the healed
  /// row, which then resolves cleanly with no further writes.
  T? _pick<T>(
    Favorite fav,
    String id,
    String keyPrefix,
    List<T> items,
    String Function(T) idOf,
    String Function(T) titleOf,
  ) {
    T? firstWhere(bool Function(T) test) =>
        items.cast<T?>().firstWhere((i) => i != null && test(i), orElse: () => null);

    final byId = firstWhere((i) => idOf(i) == id);
    if (byId != null) {
      if (fav.title.isEmpty) {
        _repair(fav, '$keyPrefix:${idOf(byId)}', titleOf(byId));
        return byId;
      }
      if (titleOf(byId) == fav.title) return byId;
      final byTitle = firstWhere((i) => titleOf(i) == fav.title);
      if (byTitle != null) {
        _repair(fav, '$keyPrefix:${idOf(byTitle)}', fav.title);
        return byTitle;
      }
      _repair(fav, '$keyPrefix:${idOf(byId)}', titleOf(byId));
      return byId;
    }
    if (fav.title.isEmpty) return null;
    final byTitle = firstWhere((i) => titleOf(i) == fav.title);
    if (byTitle != null) {
      _repair(fav, '$keyPrefix:${idOf(byTitle)}', fav.title);
      return byTitle;
    }
    return null;
  }

  void _repair(Favorite fav, String newItemKey, String title) {
    if (newItemKey == fav.itemKey && title == fav.title) return;
    appLog.info(
        'favorites: heal ${fav.itemKey} -> $newItemKey title="$title"');
    unawaited(_content.repairFavorite(
      oldItemKey: fav.itemKey,
      newItemKey: newItemKey,
      title: title,
    ));
  }

  GridEntry? _resolve(Favorite fav) {
    final parts = fav.itemKey.split(':');
    if (parts.length < 2) return null;
    final kindStr = parts[0];
    final id = parts.sublist(1).join(':');

    switch (kindStr) {
      case 'movie':
        final movie =
            _pick(fav, id, kindStr, _movies, (m) => m.id, (m) => m.title);
        if (movie == null) return null;
        return GridEntry(
          id: movie.id,
          playlistId: movie.playlistId,
          title: movie.title,
          subtitle: movie.year,
          posterUrl: movie.posterUrl,
          // Without this the detail screen receives an empty URL and playback
          // fails with "invalid or unsupported media" — the same movie opened
          // from Movies plays, because the grid does carry it.
          streamUrl: movie.streamUrl,
        );

      // Series are favorited as `episode:<seriesId>` app-wide (grid, search and
      // details all use that key), so resolve both prefixes against series.
      case 'series':
      case 'episode':
        final show =
            _pick(fav, id, kindStr, _series, (s) => s.id, (s) => s.title);
        if (show == null) return null;
        return GridEntry(
          id: show.id,
          playlistId: show.playlistId,
          title: show.title,
          subtitle: show.year,
          posterUrl: show.posterUrl,
          isSeries: true,
        );

      case 'channel':
        final ch =
            _pick(fav, id, kindStr, _channels, (c) => c.id, (c) => c.name);
        if (ch == null) return null;
        return GridEntry(
          id: ch.id,
          playlistId: ch.playlistId,
          title: ch.name,
          subtitle: ch.number,
          posterUrl: ch.logoUrl,
          badge: 'LIVE',
          streamUrl: ch.streamUrl,
        );

      default:
        return null;
    }
  }

  @override
  Future<void> close() async {
    await _activeSub?.cancel();
    await _favsSub?.cancel();
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _channelsSub?.cancel();
    await _progressSub?.cancel();
    return super.close();
  }
}
