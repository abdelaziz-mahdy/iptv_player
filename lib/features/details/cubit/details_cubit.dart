import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iptv_player/core/logging/app_logger.dart';
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

  /// Provider metadata for the movie or series on screen.
  final MediaDetail info;

  /// Watch progress keyed by episode item key (`episode:<id>`), watched
  /// entries included — powers the per-episode progress indicators.
  final Map<String, WatchProgress> progressByKey;

  const DetailsState({
    this.loading = false,
    this.seasons = const [],
    this.selectedSeasonIndex = 0,
    this.episodes = const [],
    this.info = MediaDetail.empty,
    this.progressByKey = const {},
  });

  DetailsState copyWith({
    bool? loading,
    List<Season>? seasons,
    int? selectedSeasonIndex,
    List<Episode>? episodes,
    MediaDetail? info,
    Map<String, WatchProgress>? progressByKey,
  }) {
    return DetailsState(
      loading: loading ?? this.loading,
      seasons: seasons ?? this.seasons,
      selectedSeasonIndex: selectedSeasonIndex ?? this.selectedSeasonIndex,
      episodes: episodes ?? this.episodes,
      info: info ?? this.info,
      progressByKey: progressByKey ?? this.progressByKey,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    seasons,
    selectedSeasonIndex,
    episodes,
    info,
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
    final detail = result.when(ok: (d) => d, err: (_) => const SeriesDetail());

    _episodesBySeason = detail.episodesBySeason;
    final seasons = detail.seasons;
    final firstEpisodes = seasons.isEmpty
        ? const <Episode>[]
        : (_episodesBySeason[seasons.first.id] ?? const []);

    emit(
      state.copyWith(
        loading: false,
        seasons: seasons,
        selectedSeasonIndex: 0,
        episodes: firstEpisodes,
        info: detail.info,
      ),
    );
  }

  /// Fetches a movie's extended metadata (plot, cast, genre, runtime...).
  /// Failures are already absorbed by the repository — an empty result just
  /// means the provider supplied nothing.
  Future<void> loadMovie(VodItem movie) async {
    emit(state.copyWith(loading: true));
    final result = await _content.loadMovieDetail(movie);
    if (isClosed) return;
    emit(
      state.copyWith(
        loading: false,
        info: result.when(ok: (d) => d, err: (_) => MediaDetail.empty),
      ),
    );
  }

  /// Every episode of the series in playback order, seasons concatenated.
  ///
  /// This is the queue handed to the player: Previous/Next then continue past
  /// a season boundary instead of dead-ending on the last episode of the
  /// season that happened to be on screen.
  List<Episode> get allEpisodes => [
    for (final s in state.seasons) ...(_episodesBySeason[s.id] ?? const []),
  ];

  /// Position of [episode] within [allEpisodes]; -1 when it is not found.
  int indexInSeries(Episode episode) =>
      allEpisodes.indexWhere((e) => e.id == episode.id);

  String? _lastPlayTargetLog;

  /// Where the header Play button should start: decided by the episode
  /// played most recently. Unfinished: resume it. Finished: the episode after
  /// it (crossing into the next season), or the first episode when it was the
  /// last one. No progress: the first episode. [episodes] is the whole series
  /// in order (see [allEpisodes]), so Next keeps working across seasons.
  /// Returns null when the series has no episodes.
  ///
  /// Only the newest row counts: an older episode left part-watched must not
  /// pull Play back once later episodes have been finished.
  ({
    List<Episode> episodes,
    int episodeIndex,
    int seasonNumber,
    int episodeNumber,
    bool isResume,
    bool isRestart,
  })?
  playTarget() {
    if (state.seasons.isEmpty) return null;

    WatchProgress? newest;
    (int, int)? newestAt;
    for (var s = 0; s < state.seasons.length; s++) {
      final eps = _episodesBySeason[state.seasons[s].id] ?? const [];
      for (var e = 0; e < eps.length; e++) {
        final p = state.progressByKey['episode:${eps[e].id}'];
        if (p == null || (!p.isWatched && p.positionSec <= 0)) continue;
        // Ties go to the later episode.
        if (newest == null || !p.updatedAt.isBefore(newest.updatedAt)) {
          newest = p;
          newestAt = (s, e);
        }
      }
    }

    var target = (0, 0);
    final isResume = newest != null && !newest.isWatched;
    var isRestart = false;
    if (newestAt != null) {
      final (s, e) = newestAt;
      if (isResume) {
        target = newestAt;
      } else {
        final eps = _episodesBySeason[state.seasons[s].id] ?? const [];
        if (e + 1 < eps.length) {
          target = (s, e + 1);
        } else if (s + 1 < state.seasons.length) {
          target = (s + 1, 0);
        } else {
          isRestart = true; // the last episode was finished: start over.
        }
      }
    }

    final seasonEpisodes =
        _episodesBySeason[state.seasons[target.$1].id] ?? const [];
    // Forensics for "Play did not continue where I left off": the decision
    // depends on progress rows keyed by episode id, and providers renumber
    // those ids across catalog refreshes (see the favorites fix, cb5aa89) —
    // stale keys silently degrade this to "start from the beginning".
    final known = state.seasons
        .expand((s) => _episodesBySeason[s.id] ?? const <Episode>[])
        .where((e) => state.progressByKey.containsKey('episode:${e.id}'))
        .length;
    final decision =
        'playTarget seasons=${state.seasons.length} '
        'progressRows=${state.progressByKey.length} matchedEpisodes=$known '
        'newestAt=$newestAt watched=${newest?.isWatched} -> '
        'season=${target.$1} episode=${target.$2}';
    // Called from build, and progress is saved every 10 s during playback:
    // log the decision when it changes, not on every rebuild.
    if (decision != _lastPlayTargetLog) {
      _lastPlayTargetLog = decision;
      appLog.info(decision);
    }
    if (seasonEpisodes.isEmpty || target.$2 >= seasonEpisodes.length) {
      return null;
    }
    final all = allEpisodes;
    final index = all.indexWhere((e) => e.id == seasonEpisodes[target.$2].id);
    if (index < 0) return null;
    return (
      episodes: all,
      episodeIndex: index,
      seasonNumber: state.seasons[target.$1].number,
      episodeNumber: seasonEpisodes[target.$2].number,
      isResume: isResume,
      isRestart: isRestart,
    );
  }

  /// Switches to the season at [index] using the cached episode map.
  void selectSeason(int index) {
    if (index < 0 || index >= state.seasons.length) return;
    final episodes = _episodesBySeason[state.seasons[index].id] ?? const [];
    emit(state.copyWith(selectedSeasonIndex: index, episodes: episodes));
  }

  void _onProgress(List<WatchProgress> rows) {
    if (isClosed) return;
    emit(state.copyWith(progressByKey: {for (final p in rows) p.itemKey: p}));
  }

  @override
  Future<void> close() async {
    await _progressSub?.cancel();
    return super.close();
  }
}
