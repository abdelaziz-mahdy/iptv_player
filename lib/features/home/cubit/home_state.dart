part of 'home_cubit.dart';

class HomeState extends Equatable {
  const HomeState({
    this.loading = false,
    this.movies = const [],
    this.series = const [],
    this.continueWatching = const [],
    this.episodesById = const {},
    this.favoriteKeys = const {},
  });

  final bool loading;
  final List<VodItem> movies;
  final List<Series> series;
  final List<WatchProgress> continueWatching;

  /// Cached episodes for Continue Watching entries, keyed by episode domain id,
  /// so a series episode can show "S{season} · E{number}".
  final Map<String, Episode> episodesById;

  /// Set of favorited itemKeys (e.g. "movie:m1", "episode:s1").
  final Set<String> favoriteKeys;

  HomeState copyWith({
    bool? loading,
    List<VodItem>? movies,
    List<Series>? series,
    List<WatchProgress>? continueWatching,
    Map<String, Episode>? episodesById,
    Set<String>? favoriteKeys,
  }) {
    return HomeState(
      loading: loading ?? this.loading,
      movies: movies ?? this.movies,
      series: series ?? this.series,
      continueWatching: continueWatching ?? this.continueWatching,
      episodesById: episodesById ?? this.episodesById,
      favoriteKeys: favoriteKeys ?? this.favoriteKeys,
    );
  }

  @override
  List<Object> get props => [
        loading,
        movies,
        series,
        continueWatching,
        episodesById,
        favoriteKeys,
      ];
}
