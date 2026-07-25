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
  final List<GridEntry> entries;

  const FavoritesState({
    this.loading = false,
    this.entries = const [],
  });

  bool get isEmpty => entries.isEmpty;

  FavoritesState copyWith({
    bool? loading,
    List<GridEntry>? entries,
  }) {
    return FavoritesState(
      loading: loading ?? this.loading,
      entries: entries ?? this.entries,
    );
  }

  @override
  List<Object?> get props => [loading, entries];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(this._content, this._playlists)
      : super(const FavoritesState());

  final ContentRepository _content;
  final PlaylistRepository _playlists;

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
    _favorites = [];
    _movies = [];
    _series = [];
    _channels = [];

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
      _rebuild();
    });

    _seriesSub = _content.series(pid).listen((series) {
      _series = series;
      _rebuild();
    });

    _channelsSub = _content.channels(pid).listen((channels) {
      _channels = channels;
      _rebuild();
    });
  }

  /// Unresolvable favorites already logged this session (avoid re-logging on
  /// every stream emission).
  final Set<String> _loggedMissing = {};

  void _rebuild() {
    final entries = <GridEntry>[];
    for (final fav in _favorites) {
      final entry = _resolve(fav);
      if (entry != null) {
        entries.add(entry);
      } else if (_loggedMissing.add(fav.itemKey)) {
        appLog.warning(
            'favorites: ${fav.itemKey} title="${fav.title}" unresolvable — hidden');
      }
    }
    emit(state.copyWith(loading: false, entries: entries));
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
    return super.close();
  }
}
