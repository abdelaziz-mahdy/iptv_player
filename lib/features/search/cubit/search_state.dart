part of 'search_cubit.dart';

enum SearchEntryKind { movie, series, channel }

class SearchEntry extends Equatable {
  const SearchEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.posterUrl,
    required this.kind,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? posterUrl;
  final SearchEntryKind kind;

  @override
  List<Object?> get props => [id, title, subtitle, posterUrl, kind];
}

class SearchState extends Equatable {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
  });

  final String query;
  final List<SearchEntry> results;
  final bool loading;

  SearchState copyWith({
    String? query,
    List<SearchEntry>? results,
    bool? loading,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object> get props => [query, results, loading];
}
