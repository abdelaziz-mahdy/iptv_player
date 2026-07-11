import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/repositories.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class DetailsState extends Equatable {
  final bool loading;
  final List<Season> seasons;
  final int selectedSeasonIndex;
  final List<Episode> episodes;
  final String? description;

  /// Watch progress keyed by episode item key (`episode:<id>`), watched
  /// entries included — powers the per-episode progress indicators.
  final Map<String, WatchProgress> progressByKey;

  const DetailsState({
    this.loading = false,
    this.seasons = const [],
    this.selectedSeasonIndex = 0,
    this.episodes = const [],
    this.description,
    this.progressByKey = const {},
  });

  DetailsState copyWith({
    bool? loading,
    List<Season>? seasons,
    int? selectedSeasonIndex,
    List<Episode>? episodes,
    String? description,
    Map<String, WatchProgress>? progressByKey,
  }) {
    return DetailsState(
      loading: loading ?? this.loading,
      seasons: seasons ?? this.seasons,
      selectedSeasonIndex: selectedSeasonIndex ?? this.selectedSeasonIndex,
      episodes: episodes ?? this.episodes,
      description: description ?? this.description,
      progressByKey: progressByKey ?? this.progressByKey,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        seasons,
        selectedSeasonIndex,
        episodes,
        description,
        progressByKey,
      ];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class DetailsCubit extends Cubit<DetailsState> {
  final ContentRepository _content;
  final PlaybackRepository _playback;

  DetailsCubit(this._content, this._playback) : super(const DetailsState());

  /// Episodes keyed by season domain id, cached from [loadSeries] so switching
  /// seasons is instant (no extra fetch).
  Map<String, List<Episode>> _episodesBySeason = const {};

  StreamSubscription<List<WatchProgress>>? _progressSub;

  /// Fetches the series' seasons + episodes on demand (Xtream series-info),
  /// then shows the first season. For movie detail screens, no load is needed.
  Future<void> loadSeries(Series series) async {
    emit(state.copyWith(loading: true));

    // Live progress so episode indicators refresh when returning from the
    // player.
    _progressSub ??= _playback
        .progressForPlaylist(series.playlistId)
        .listen(_onProgress);

    final result = await _content.loadSeriesDetail(series);
    final detail = result.when(
      ok: (d) => d,
      err: (_) => const SeriesDetail(),
    );

    _episodesBySeason = detail.episodesBySeason;
    final seasons = detail.seasons;
    final firstEpisodes = seasons.isEmpty
        ? const <Episode>[]
        : (_episodesBySeason[seasons.first.id] ?? const []);

    emit(state.copyWith(
      loading: false,
      seasons: seasons,
      selectedSeasonIndex: 0,
      episodes: firstEpisodes,
      description: detail.description,
    ));
  }

  /// Switches to the season at [index] using the cached episode map.
  void selectSeason(int index) {
    if (index < 0 || index >= state.seasons.length) return;
    final episodes = _episodesBySeason[state.seasons[index].id] ?? const [];
    emit(state.copyWith(selectedSeasonIndex: index, episodes: episodes));
  }

  void _onProgress(List<WatchProgress> rows) {
    if (isClosed) return;
    emit(state.copyWith(
      progressByKey: {for (final p in rows) p.itemKey: p},
    ));
  }

  @override
  Future<void> close() async {
    await _progressSub?.cancel();
    return super.close();
  }
}
