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

  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<WatchProgress>>? _continueSub;
  StreamSubscription<List<Favorite>>? _favoritesSub;
  String? _playlistId;

  Future<void> load() async {
    emit(state.copyWith(loading: true));

    final pid = (await _playlists.active().first)?.id ?? 'p1';
    _playlistId = pid;

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
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _continueSub?.cancel();
    await _favoritesSub?.cancel();
    return super.close();
  }
}
