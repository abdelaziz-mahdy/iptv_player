import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

// ── State ──────────────────────────────────────────────────────────────────

class PlaylistsState extends Equatable {
  final List<Playlist> playlists;
  final String? activeId;
  final bool loading;

  const PlaylistsState({
    this.playlists = const [],
    this.activeId,
    this.loading = false,
  });

  PlaylistsState copyWith({
    List<Playlist>? playlists,
    String? activeId,
    bool? loading,
  }) {
    return PlaylistsState(
      playlists: playlists ?? this.playlists,
      activeId: activeId ?? this.activeId,
      loading: loading ?? this.loading,
    );
  }

  @override
  List<Object?> get props => [playlists, activeId, loading];
}

// ── Cubit ──────────────────────────────────────────────────────────────────

class PlaylistsCubit extends Cubit<PlaylistsState> {
  final PlaylistRepository _playlists;

  PlaylistsCubit(this._playlists) : super(const PlaylistsState());

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    final result = await _playlists.all();
    String? activeId;
    // get active from stream (first value)
    await _playlists.active().first.then((p) => activeId = p?.id);
    result.when(
      ok: (list) => emit(PlaylistsState(playlists: list, activeId: activeId)),
      err: (f) => emit(state.copyWith(loading: false)),
    );
  }

  Future<void> select(String id) async {
    await _playlists.setActive(id);
    emit(state.copyWith(activeId: id));
  }

  Future<void> delete(String id) async {
    await _playlists.remove(id);
    await load();
  }
}
