import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  StreamSubscription<List<Favorite>>? _favsSub;
  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<Channel>>? _channelsSub;

  // latest snapshots
  List<Favorite> _favorites = [];
  List<VodItem> _movies = [];
  List<Series> _series = [];
  List<Channel> _channels = [];

  Future<void> load() async {
    emit(state.copyWith(loading: true));

    final pid = (await _playlists.active().first)?.id ?? 'p1';

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

  void _rebuild() {
    final entries = <GridEntry>[];
    for (final fav in _favorites) {
      final entry = _resolve(fav);
      if (entry != null) entries.add(entry);
    }
    emit(state.copyWith(loading: false, entries: entries));
  }

  GridEntry? _resolve(Favorite fav) {
    final parts = fav.itemKey.split(':');
    if (parts.length < 2) return null;
    final kindStr = parts[0];
    final id = parts.sublist(1).join(':');

    switch (kindStr) {
      case 'movie':
        final movie =
            _movies.cast<VodItem?>().firstWhere((m) => m?.id == id, orElse: () => null);
        if (movie == null) return null;
        return GridEntry(
          id: movie.id,
          title: movie.title,
          subtitle: movie.year,
          posterUrl: movie.posterUrl,
        );

      case 'series':
        final show =
            _series.cast<Series?>().firstWhere((s) => s?.id == id, orElse: () => null);
        if (show == null) return null;
        return GridEntry(
          id: show.id,
          title: show.title,
          subtitle: show.year,
          posterUrl: show.posterUrl,
        );

      case 'channel':
        final ch = _channels
            .cast<Channel?>()
            .firstWhere((c) => c?.id == id, orElse: () => null);
        if (ch == null) return null;
        return GridEntry(
          id: ch.id,
          title: ch.name,
          subtitle: ch.number,
          posterUrl: ch.logoUrl,
          badge: 'LIVE',
        );

      default:
        return null;
    }
  }

  @override
  Future<void> close() async {
    await _favsSub?.cancel();
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _channelsSub?.cancel();
    return super.close();
  }
}
