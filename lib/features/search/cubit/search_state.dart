part of 'search_cubit.dart';

enum SearchEntryKind { movie, series, channel }

class SearchEntry extends Equatable {
  const SearchEntry({
    required this.id,
    required this.playlistId,
    required this.title,
    this.subtitle,
    this.posterUrl,
    required this.kind,
    this.streamUrl,
  });

  final String id;
  final String playlistId;
  final String title;
  final String? subtitle;
  final String? posterUrl;
  final SearchEntryKind kind;
  final String? streamUrl;

  @override
  List<Object?> get props =>
      [id, playlistId, title, subtitle, posterUrl, kind, streamUrl];
}

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
    this.favoriteKeys = const {},
  });

  final String query;
  final List<SearchEntry> results;
  final bool loading;

  /// Set of favorited itemKeys (e.g. "movie:m1", "episode:s1").
  final Set<String> favoriteKeys;

  SearchState copyWith({
    String? query,
    List<SearchEntry>? results,
    bool? loading,
    Set<String>? favoriteKeys,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
      favoriteKeys: favoriteKeys ?? this.favoriteKeys,
    );
  }

  @override
  List<Object> get props => [query, results, loading, favoriteKeys];
}
