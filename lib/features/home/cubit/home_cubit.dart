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
  StreamSubscription<List<Channel>>? _channelsSub;
  StreamSubscription<List<WatchProgress>>? _continueSub;

  Future<void> load() async {
    emit(state.copyWith(loading: true));

    final pid = (await _playlists.active().first)?.id ?? 'p1';

    _moviesSub = _content.movies(pid).listen(
      (movies) => emit(state.copyWith(movies: movies, loading: false)),
    );
    _seriesSub = _content.series(pid).listen(
      (series) => emit(state.copyWith(series: series)),
    );
    _channelsSub = _content.channels(pid).listen(
      (channels) => emit(state.copyWith(channels: channels)),
    );
    _continueSub = _playback.continueWatching(pid).listen(
      (cw) => emit(state.copyWith(continueWatching: cw)),
    );
  }

  @override
  Future<void> close() async {
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _channelsSub?.cancel();
    await _continueSub?.cancel();
    return super.close();
  }
}
