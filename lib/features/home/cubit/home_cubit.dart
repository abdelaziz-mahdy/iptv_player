import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

part 'home_state.dart';

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
      emit(state.copyWith(
        movies: const [],
        series: const [],
        continueWatching: const [],
        favoriteKeys: const {},
        loading: false,
      ));
      return;
    }

    _moviesSub = _content.movies(pid).listen(
      (movies) => emit(state.copyWith(movies: movies, loading: false)),
    );
    _seriesSub = _content.series(pid).listen(
      (series) => emit(state.copyWith(series: series)),
    );
    _continueSub = _playback.continueWatching(pid).listen(
      (cw) => emit(state.copyWith(continueWatching: cw)),
    );
    _favoritesSub = _content.favorites(pid).listen(
      (favs) => emit(
        state.copyWith(favoriteKeys: favs.map((f) => f.itemKey).toSet()),
      ),
    );
  }

  Future<void> removeFromContinueWatching(String itemKey) async {
    await _playback.removeProgress(itemKey);
  }

  /// Toggles favorite for a movie item.
  /// Keyed as `movie:<id>` with [MediaKind.movie].
  Future<void> toggleFavoriteMovie(VodItem movie) async {
    final pid = _playlistId ?? 'p1';
    await _content.toggleFavorite('movie:${movie.id}', pid, MediaKind.movie);
  }

  /// Toggles favorite for a series item.
  /// Keyed as `episode:<id>` with [MediaKind.episode] — matching the convention
  /// used in the details screen.
  Future<void> toggleFavoriteSeries(Series series) async {
    final pid = _playlistId ?? 'p1';
    await _content.toggleFavorite('episode:${series.id}', pid, MediaKind.episode);
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
