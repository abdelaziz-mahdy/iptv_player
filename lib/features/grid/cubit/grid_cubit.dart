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
  final String playlistId;
  final String title;
  final String? subtitle;
  final String? posterUrl;
  final String? badge;
  final String? streamUrl;
  final bool isSeries;

  const GridEntry({
    required this.id,
    required this.playlistId,
    required this.title,
    this.subtitle,
    this.posterUrl,
    this.badge,
    this.streamUrl,
    this.isSeries = false,
  });

  @override
  List<Object?> get props =>
      [id, playlistId, title, subtitle, posterUrl, badge, streamUrl, isSeries];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Id of the synthetic "Recently Viewed" category pinned at the top of the
/// sidebar. Selecting it shows [GridState.recentItems].
const kRecentCategoryId = '__recent__';

class GridState extends Equatable {
  final bool loading;
  final List<GridEntry> items;

  /// Category chips: optional "Recently Viewed" first, then synthetic "All",
  /// then resolved provider categories — each with a [CategoryRef.count].
  final List<CategoryRef> categories;

  /// The id of the currently selected category, null when "All" is active, or
  /// [kRecentCategoryId] when the pinned "Recently Viewed" category is active.
  final String? selectedCategoryId;

  /// Items previously opened in the player, most-recent first.
  final List<GridEntry> recentItems;

  /// The set of favorited itemKeys (e.g. "movie:m1") for this grid.
  final Set<String> favoriteKeys;

  const GridState({
    this.loading = false,
    this.items = const [],
    this.categories = const [],
    this.selectedCategoryId,
    this.recentItems = const [],
    this.favoriteKeys = const {},
  });

  GridState copyWith({
    bool? loading,
    List<GridEntry>? items,
    List<CategoryRef>? categories,
    String? selectedCategoryId,
    bool clearCategory = false,
    List<GridEntry>? recentItems,
    Set<String>? favoriteKeys,
  }) {
    return GridState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      categories: categories ?? this.categories,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      recentItems: recentItems ?? this.recentItems,
      favoriteKeys: favoriteKeys ?? this.favoriteKeys,
    );
  }

  List<GridEntry> get filteredItems {
    if (selectedCategoryId == kRecentCategoryId) return recentItems;
    if (selectedCategoryId == null) return items;
    return items.where((e) => e.badge == selectedCategoryId).toList();
  }

  @override
  List<Object?> get props =>
      [loading, items, categories, selectedCategoryId, recentItems, favoriteKeys];
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

class GridCubit extends Cubit<GridState> {
  GridCubit(this._content, this._playlists, this.kind, {this._playback})
      : super(const GridState());

  final ContentRepository _content;
  final PlaylistRepository _playlists;

  /// Optional — when provided, powers the pinned "Recently Viewed" category.
  final PlaybackRepository? _playback;
  final GridKind kind;

  StreamSubscription<Playlist?>? _activeSub;
  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<Favorite>>? _favoritesSub;
  StreamSubscription<List<String>>? _recentSub;
  String? _playlistId;
  bool _hasBound = false;

  // Raw inputs, recombined by [_recompute] into the emitted state.
  List<GridEntry> _rawItems = const [];
  List<CategoryRef> _resolvedCats = const [];
  List<String> _recentKeys = const [];

  /// Key prefix for this section's browsable items (`movie:` / `series:`).
  String get _recentPrefix => kind == GridKind.movies ? 'movie:' : 'series:';

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
    await _recentSub?.cancel();
    _recentSub = null;
    _rawItems = const [];
    _recentKeys = const [];

    if (pid == null) {
      emit(state.copyWith(
        loading: false,
        items: const [],
        categories: const [],
        recentItems: const [],
        favoriteKeys: const {},
      ));
      return;
    }

    // Determine the MediaKind for category resolution.
    final mediaKind = kind == GridKind.movies ? MediaKind.movie : MediaKind.episode;

    // Load categories eagerly so they're available when stream emits.
    _resolvedCats = await _content.categories(pid, mediaKind);

    // Subscribe to favorites stream.
    _favoritesSub = _content.favorites(pid).listen(
      (favs) => emit(
        state.copyWith(favoriteKeys: favs.map((f) => f.itemKey).toSet()),
      ),
    );

    // Subscribe to recently-viewed (optional dependency).
    _recentSub = _playback?.recentlyViewed(pid).listen((keys) {
      _recentKeys = keys;
      _recompute();
    });

    switch (kind) {
      case GridKind.movies:
        _moviesSub = _content.movies(pid).listen(_onMovies);
      case GridKind.series:
        _seriesSub = _content.series(pid).listen(_onSeries);
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

  void _onMovies(List<VodItem> movies) {
    _rawItems = movies
        .map(
          (m) => GridEntry(
            id: m.id,
            playlistId: m.playlistId,
            title: m.title,
            subtitle: m.year,
            posterUrl: m.posterUrl,
            badge: m.categoryId, // used for filtering; no visible badge for movies
            streamUrl: m.streamUrl,
            isSeries: false,
          ),
        )
        .toList();
    _recompute();
  }

  void _onSeries(List<Series> series) {
    _rawItems = series
        .map(
          (s) => GridEntry(
            id: s.id,
            playlistId: s.playlistId,
            title: s.title,
            subtitle: s.year,
            posterUrl: s.posterUrl,
            badge: s.categoryId,
            streamUrl: null,
            isSeries: true,
          ),
        )
        .toList();
    _recompute();
  }

  /// Rebuilds the emitted state from the raw items, resolved categories and
  /// recent keys: computes per-category counts and the pinned "Recently
  /// Viewed" category/items.
  void _recompute() {
    final byId = {for (final e in _rawItems) e.id: e};

    // Recent items in recency order, de-duped, only those still present.
    final recent = <GridEntry>[];
    final seen = <String>{};
    for (final key in _recentKeys) {
      if (!key.startsWith(_recentPrefix)) continue;
      final id = key.substring(_recentPrefix.length);
      final entry = byId[id];
      if (entry != null && seen.add(id)) recent.add(entry);
    }

    // Per-category counts.
    final counts = <String, int>{};
    for (final e in _rawItems) {
      final b = e.badge;
      if (b != null && b.isNotEmpty) counts[b] = (counts[b] ?? 0) + 1;
    }

    final cats = <CategoryRef>[
      if (recent.isNotEmpty)
        CategoryRef(
          id: kRecentCategoryId,
          name: 'Recently Viewed',
          count: recent.length,
        ),
      CategoryRef(id: '', name: 'All', count: _rawItems.length),
      for (final c in _resolvedCats) c.copyWith(count: counts[c.id] ?? 0),
    ];

    emit(state.copyWith(
      loading: false,
      items: _rawItems,
      categories: cats,
      recentItems: recent,
    ));
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
    await _recentSub?.cancel();
    return super.close();
  }
}
