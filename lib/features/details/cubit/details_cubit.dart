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

  const DetailsState({
    this.loading = false,
    this.seasons = const [],
    this.selectedSeasonIndex = 0,
    this.episodes = const [],
    this.description,
  });

  DetailsState copyWith({
    bool? loading,
    List<Season>? seasons,
    int? selectedSeasonIndex,
    List<Episode>? episodes,
    String? description,
  }) {
    return DetailsState(
      loading: loading ?? this.loading,
      seasons: seasons ?? this.seasons,
      selectedSeasonIndex: selectedSeasonIndex ?? this.selectedSeasonIndex,
      episodes: episodes ?? this.episodes,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props =>
      [loading, seasons, selectedSeasonIndex, episodes, description];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class DetailsCubit extends Cubit<DetailsState> {
  final ContentRepository _content;

  DetailsCubit(this._content) : super(const DetailsState());

  /// Episodes keyed by season domain id, cached from [loadSeries] so switching
  /// seasons is instant (no extra fetch).
  Map<String, List<Episode>> _episodesBySeason = const {};

  /// Fetches the series' seasons + episodes on demand (Xtream series-info),
  /// then shows the first season. For movie detail screens, no load is needed.
  Future<void> loadSeries(Series series) async {
    emit(state.copyWith(loading: true));

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
}
