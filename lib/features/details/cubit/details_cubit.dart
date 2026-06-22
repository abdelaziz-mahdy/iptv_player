import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/data/repositories/repositories.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class DetailsState extends Equatable {
  final bool loading;
  final List<Season> seasons;
  final int selectedSeasonIndex;
  final List<Episode> episodes;

  const DetailsState({
    this.loading = false,
    this.seasons = const [],
    this.selectedSeasonIndex = 0,
    this.episodes = const [],
  });

  DetailsState copyWith({
    bool? loading,
    List<Season>? seasons,
    int? selectedSeasonIndex,
    List<Episode>? episodes,
  }) {
    return DetailsState(
      loading: loading ?? this.loading,
      seasons: seasons ?? this.seasons,
      selectedSeasonIndex: selectedSeasonIndex ?? this.selectedSeasonIndex,
      episodes: episodes ?? this.episodes,
    );
  }

  @override
  List<Object?> get props => [loading, seasons, selectedSeasonIndex, episodes];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class DetailsCubit extends Cubit<DetailsState> {
  final ContentRepository _content;

  DetailsCubit(this._content) : super(const DetailsState());

  /// Loads seasons for the given series, then loads episodes for the first
  /// season. For movie detail screens, no load is needed.
  Future<void> loadSeries(String seriesId) async {
    emit(state.copyWith(loading: true));

    final seasonsResult = await _content.seasons(seriesId);
    final seasons = seasonsResult.when(
      ok: (list) => list,
      err: (_) => <Season>[],
    );

    if (seasons.isEmpty) {
      emit(state.copyWith(loading: false, seasons: seasons, episodes: []));
      return;
    }

    final episodesResult = await _content.episodes(seasons.first.id);
    final episodes = episodesResult.when(
      ok: (list) => list,
      err: (_) => <Episode>[],
    );

    emit(state.copyWith(
      loading: false,
      seasons: seasons,
      selectedSeasonIndex: 0,
      episodes: episodes,
    ));
  }

  /// Switches to the season at [index] and loads its episodes.
  Future<void> selectSeason(int index) async {
    if (index < 0 || index >= state.seasons.length) return;

    emit(state.copyWith(loading: true, selectedSeasonIndex: index));

    final episodesResult = await _content.episodes(state.seasons[index].id);
    final episodes = episodesResult.when(
      ok: (list) => list,
      err: (_) => <Episode>[],
    );

    emit(state.copyWith(loading: false, episodes: episodes));
  }
}
