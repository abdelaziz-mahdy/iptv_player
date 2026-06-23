part of 'home_cubit.dart';

class HomeState extends Equatable {
  const HomeState({
    this.loading = false,
    this.movies = const [],
    this.series = const [],
    this.continueWatching = const [],
  });

  final bool loading;
  final List<VodItem> movies;
  final List<Series> series;
  final List<WatchProgress> continueWatching;

  HomeState copyWith({
    bool? loading,
    List<VodItem>? movies,
    List<Series>? series,
    List<WatchProgress>? continueWatching,
  }) {
    return HomeState(
      loading: loading ?? this.loading,
      movies: movies ?? this.movies,
      series: series ?? this.series,
      continueWatching: continueWatching ?? this.continueWatching,
    );
  }

  @override
  List<Object> get props => [loading, movies, series, continueWatching];
}
