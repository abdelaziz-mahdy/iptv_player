import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._content, this._playlists) : super(const SearchState());

  final ContentRepository _content;
  final PlaylistRepository _playlists;

  // Cached content
  List<SearchEntry> _allEntries = const [];
  List<VodItem> _movies = const [];
  List<Series> _series = const [];
  StreamSubscription<Playlist?>? _activeSub;
  StreamSubscription<List<VodItem>>? _moviesSub;
  StreamSubscription<List<Series>>? _seriesSub;
  StreamSubscription<List<Favorite>>? _favoritesSub;
  String? _playlistId;
  bool _hasBound = false;

  /// React to the ACTIVE playlist so search covers the imported/switched
  /// playlist live, without an app restart.
  Future<void> load() async {
    emit(state.copyWith(loading: true));
    _activeSub = _playlists.active().listen(_onActivePlaylistChanged);
  }

  void _onActivePlaylistChanged(Playlist? playlist) {
    final pid = playlist?.id;
    if (_hasBound && pid == _playlistId) return;
    _hasBound = true;
    _playlistId = pid;

    _moviesSub?.cancel();
    _seriesSub?.cancel();
    _favoritesSub?.cancel();
    _movies = const [];
    _series = const [];
    _allEntries = const [];

    if (pid == null) {
      emit(state.copyWith(
          loading: false, results: const [], favoriteKeys: const {}));
      return;
    }

    _moviesSub = _content.movies(pid).listen((m) {
      _movies = m;
      _rebuildEntries();
    });
    _seriesSub = _content.series(pid).listen((s) {
      _series = s;
      _rebuildEntries();
    });
    _favoritesSub = _content.favorites(pid).listen(
      (favs) => emit(
        state.copyWith(favoriteKeys: favs.map((f) => f.itemKey).toSet()),
      ),
    );
  }

  void _rebuildEntries() {
    _allEntries = [
      ..._movies.map(
        (m) => SearchEntry(
          id: m.id,
          title: m.title,
          subtitle: m.year,
          posterUrl: m.posterUrl,
          kind: SearchEntryKind.movie,
          streamUrl: m.streamUrl,
        ),
      ),
      ..._series.map(
        (s) => SearchEntry(
          id: s.id,
          title: s.title,
          subtitle: s.year,
          posterUrl: s.posterUrl,
          kind: SearchEntryKind.series,
          streamUrl: null,
        ),
      ),
      // Live channels are excluded from VOD/series search results.
    ];
    emit(state.copyWith(loading: false));
    // Re-apply the current query against the refreshed catalog.
    if (state.query.isNotEmpty) setQuery(state.query);
  }

  /// Toggles favorite for a search result entry.
  /// Movies are keyed as `movie:<id>` with [MediaKind.movie].
  /// Series are keyed as `episode:<id>` with [MediaKind.episode].
  Future<void> toggleFavorite(SearchEntry entry) async {
    final pid = _playlistId ?? 'p1';
    final isSeries = entry.kind == SearchEntryKind.series;
    final itemKey = isSeries ? 'episode:${entry.id}' : 'movie:${entry.id}';
    final mediaKind = isSeries ? MediaKind.episode : MediaKind.movie;
    await _content.toggleFavorite(itemKey, pid, mediaKind);
  }

  @override
  Future<void> close() async {
    await _activeSub?.cancel();
    await _moviesSub?.cancel();
    await _seriesSub?.cancel();
    await _favoritesSub?.cancel();
    return super.close();
  }

  /// Returns the subset of [results] whose kind matches [kind].
  static List<SearchEntry> byKind(
    List<SearchEntry> results,
    SearchEntryKind kind,
  ) =>
      results.where((e) => e.kind == kind).toList();

  void setQuery(String q) {
    if (q.isEmpty) {
      emit(state.copyWith(query: q, results: const []));
      return;
    }
    final lower = q.toLowerCase();
    final filtered = _allEntries
        .where(
          (e) => e.title.toLowerCase().contains(lower),
        )
        .toList();
    emit(state.copyWith(query: q, results: filtered));
  }
}
