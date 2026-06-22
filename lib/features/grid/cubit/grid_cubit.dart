import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

// ---------------------------------------------------------------------------
// Grid kind
// ---------------------------------------------------------------------------

enum GridKind { movies, series }

// ---------------------------------------------------------------------------
// View-model
// ---------------------------------------------------------------------------

class GridEntry extends Equatable {
  final String id;
  final String title;
  final String? subtitle;
  final String? posterUrl;
  final String? badge;
  final String? streamUrl;
  final bool isSeries;

  const GridEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.posterUrl,
    this.badge,
    this.streamUrl,
    this.isSeries = false,
  });

  @override
  List<Object?> get props => [id, title, subtitle, posterUrl, badge, streamUrl, isSeries];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class GridState extends Equatable {
  final bool loading;
  final List<GridEntry> items;
  final List<String> categories;
  final String? selectedCategory;

  const GridState({
    this.loading = false,
    this.items = const [],
    this.categories = const [],
    this.selectedCategory,
  });

  GridState copyWith({
    bool? loading,
    List<GridEntry>? items,
    List<String>? categories,
    String? selectedCategory,
    bool clearCategory = false,
  }) {
    return GridState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      categories: categories ?? this.categories,
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
    );
  }

  List<GridEntry> get filteredItems {
    if (selectedCategory == null) return items;
    return items
        .where((e) => e.badge == selectedCategory ||
            _categoryOf(e) == selectedCategory)
        .toList();
  }

  /// Badge is repurposed below for categoryId during mapping; actual badge
  /// (LIVE etc.) lives in a separate field. Here we reuse the subtitle as
  /// category hint when entries are built from movie/series categoryId.
  String? _categoryOf(GridEntry e) => null; // filtered via badge during build

  @override
  List<Object?> get props => [loading, items, categories, selectedCategory];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class GridCubit extends Cubit<GridState> {
  GridCubit(this._content, this._playlists, this.kind)
      : super(const GridState());

  final ContentRepository _content;
  final PlaylistRepository _playlists;
  final GridKind kind;

  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;

  Future<void> load() async {
    emit(state.copyWith(loading: true));

    final pid = (await _playlists.active().first)?.id ?? 'p1';

    switch (kind) {
      case GridKind.movies:
        _moviesSub = _content.movies(pid).listen(_onMovies);
      case GridKind.series:
        _seriesSub = _content.series(pid).listen(_onSeries);
    }
  }

  void _onMovies(List<VodItem> movies) {
    final entries = movies
        .map(
          (m) => GridEntry(
            id: m.id,
            title: m.title,
            subtitle: m.year,
            posterUrl: m.posterUrl,
            badge: m.categoryId, // used for filtering; no visible badge for movies
            streamUrl: m.streamUrl,
            isSeries: false,
          ),
        )
        .toList();
    final cats = _deriveCategories(
        movies.map((m) => m.categoryId).whereType<String>().toList());
    emit(state.copyWith(loading: false, items: entries, categories: cats));
  }

  void _onSeries(List<Series> series) {
    final entries = series
        .map(
          (s) => GridEntry(
            id: s.id,
            title: s.title,
            subtitle: s.year,
            posterUrl: s.posterUrl,
            badge: s.categoryId,
            streamUrl: null,
            isSeries: true,
          ),
        )
        .toList();
    final cats = _deriveCategories(
        series.map((s) => s.categoryId).whereType<String>().toList());
    emit(state.copyWith(loading: false, items: entries, categories: cats));
  }

  List<String> _deriveCategories(List<String> rawCats) {
    // deduplicate, preserve insertion order
    final seen = <String>{};
    return rawCats.where(seen.add).toList();
  }

  void selectCategory(String? category) {
    if (category == null) {
      emit(state.copyWith(clearCategory: true));
    } else {
      emit(state.copyWith(selectedCategory: category));
    }
  }

  @override
  Future<void> close() async {
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    return super.close();
  }
}
