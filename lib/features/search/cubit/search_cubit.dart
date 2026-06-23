import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/repositories.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._content, this._playlists) : super(const SearchState());

  final ContentRepository _content;
  final PlaylistRepository _playlists;

  // Cached content
  List<SearchEntry> _allEntries = const [];

  Future<void> load() async {
    emit(state.copyWith(loading: true));

    final pid = (await _playlists.active().first)?.id ?? 'p1';

    final movies = await _content.movies(pid).first;
    final series = await _content.series(pid).first;

    _allEntries = [
      ...movies.map(
        (m) => SearchEntry(
          id: m.id,
          title: m.title,
          subtitle: m.year,
          posterUrl: m.posterUrl,
          kind: SearchEntryKind.movie,
          streamUrl: m.streamUrl,
        ),
      ),
      ...series.map(
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
