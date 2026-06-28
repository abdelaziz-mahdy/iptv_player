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

/// Synthetic "All" category placed at index 0.
const _allCategory = CategoryRef(id: '', name: 'All');

class GridState extends Equatable {
  final bool loading;
  final List<GridEntry> items;

  /// Category chips including the synthetic "All" at index 0.
  /// Each entry is a [CategoryRef] with resolved human names.
  final List<CategoryRef> categories;

  /// The id of the currently selected category, or null when "All" is active.
  final String? selectedCategoryId;

  /// The set of favorited itemKeys (e.g. "movie:m1") for this grid.
  final Set<String> favoriteKeys;

  const GridState({
    this.loading = false,
    this.items = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.favoriteKeys = const {},
  });

  GridState copyWith({
    bool? loading,
    List<GridEntry>? items,
    List<CategoryRef>? categories,
    String? selectedCategoryId,
    bool clearCategory = false,
    Set<String>? favoriteKeys,
  }) {
    return GridState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      categories: categories ?? this.categories,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      favoriteKeys: favoriteKeys ?? this.favoriteKeys,
    );
  }

  List<GridEntry> get filteredItems {
    if (selectedCategoryId == null) return items;
    return items.where((e) => e.badge == selectedCategoryId).toList();
  }

  @override
  List<Object?> get props => [loading, items, categories, selectedCategoryId, favoriteKeys];
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

  StreamSubscription<Playlist?>? _activeSub;
  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<Favorite>>? _favoritesSub;
  String? _playlistId;
  bool _hasBound = false;

  /// React to the ACTIVE playlist so an imported/switched playlist shows live,
  /// without an app restart.
  Future<void> load() async {
    emit(state.copyWith(loading: true));
    _activeSub = _playlists.active().listen(_onActivePlaylistChanged);
  }

  Future<void> _onActivePlaylistChanged(Playlist? playlist) async {
    final pid = playlist?.id;
    if (_hasBound && pid == _playlistId) return;
    _hasBound = true;
    _playlistId = pid;

    await _moviesSub?.cancel();
    _moviesSub = null;
    await _seriesSub?.cancel();
    _seriesSub = null;
    await _favoritesSub?.cancel();
    _favoritesSub = null;

    if (pid == null) {
      emit(state.copyWith(
        loading: false,
        items: const [],
        categories: const [],
        favoriteKeys: const {},
      ));
      return;
    }

    // Determine the MediaKind for category resolution.
    final mediaKind = kind == GridKind.movies ? MediaKind.movie : MediaKind.episode;

    // Load categories eagerly so they're available when stream emits.
    final resolvedCats = await _content.categories(pid, mediaKind);

    // Subscribe to favorites stream.
    _favoritesSub = _content.favorites(pid).listen(
      (favs) => emit(
        state.copyWith(favoriteKeys: favs.map((f) => f.itemKey).toSet()),
      ),
    );

    switch (kind) {
      case GridKind.movies:
        _moviesSub = _content.movies(pid).listen(
          (movies) => _onMovies(movies, resolvedCats),
        );
      case GridKind.series:
        _seriesSub = _content.series(pid).listen(
          (series) => _onSeries(series, resolvedCats),
        );
    }
  }

  /// Toggles favorite for a grid entry.
  /// Movies are keyed as `movie:<id>` with [MediaKind.movie].
  /// Series are keyed as `episode:<id>` with [MediaKind.episode] — matching
  /// the convention used in the details screen.
  Future<void> toggleFavorite(GridEntry entry) async {
    final pid = _playlistId ?? 'p1';
    final itemKey = entry.isSeries ? 'episode:${entry.id}' : 'movie:${entry.id}';
    final mediaKind = entry.isSeries ? MediaKind.episode : MediaKind.movie;
    await _content.toggleFavorite(itemKey, pid, mediaKind);
  }

  void _onMovies(List<VodItem> movies, List<CategoryRef> resolvedCats) {
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
    emit(state.copyWith(
      loading: false,
      items: entries,
      categories: _buildCategoryList(resolvedCats),
    ));
  }

  void _onSeries(List<Series> series, List<CategoryRef> resolvedCats) {
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
    emit(state.copyWith(
      loading: false,
      items: entries,
      categories: _buildCategoryList(resolvedCats),
    ));
  }

  /// Prepends the synthetic "All" chip and returns the full list.
  List<CategoryRef> _buildCategoryList(List<CategoryRef> cats) {
    return [_allCategory, ...cats];
  }

  /// Select a category by its id.
  /// Pass null or an empty string to clear the filter (show All).
  void selectCategory(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) {
      emit(state.copyWith(clearCategory: true));
    } else {
      emit(state.copyWith(selectedCategoryId: categoryId));
    }
  }

  @override
  Future<void> close() async {
    await _activeSub?.cancel();
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _favoritesSub?.cancel();
    return super.close();
  }
}
