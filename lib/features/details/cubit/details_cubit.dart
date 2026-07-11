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

  /// Where the header Play button should start, based on watch progress:
  /// the most recently played unfinished episode; else the episode after the
  /// last finished one (crossing into the next season if needed); else the
  /// first episode. Returns null when the series has no episodes.
  ({List<Episode> episodes, int episodeIndex})? playTarget() {
    if (state.seasons.isEmpty) return null;

    WatchProgress? resume;
    (int, int)? resumeAt;
    (int, int)? lastWatchedAt;
    for (var s = 0; s < state.seasons.length; s++) {
      final eps = _episodesBySeason[state.seasons[s].id] ?? const [];
      for (var e = 0; e < eps.length; e++) {
        final p = state.progressByKey['episode:${eps[e].id}'];
        if (p == null) continue;
        if (p.isWatched) {
          lastWatchedAt = (s, e);
        } else if (p.positionSec > 0 &&
            (resume == null || p.updatedAt.isAfter(resume.updatedAt))) {
          resume = p;
          resumeAt = (s, e);
        }
      }
    }

    var target = (0, 0);
    if (resumeAt != null) {
      target = resumeAt;
    } else if (lastWatchedAt != null) {
      final (s, e) = lastWatchedAt;
      final eps = _episodesBySeason[state.seasons[s].id] ?? const [];
      if (e + 1 < eps.length) {
        target = (s, e + 1);
      } else if (s + 1 < state.seasons.length) {
        target = (s + 1, 0);
      }
      // else: everything watched — start over from the first episode.
    }

    final eps = _episodesBySeason[state.seasons[target.$1].id] ?? const [];
    if (eps.isEmpty || target.$2 >= eps.length) return null;
    return (episodes: eps, episodeIndex: target.$2);
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
