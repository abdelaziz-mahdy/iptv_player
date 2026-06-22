import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

// ── State ──────────────────────────────────────────────────────────────────

enum ImportTab { xtream, m3u, upload }

class ImportState extends Equatable {
  final ImportTab tab;
  final bool submitting;
  final String? error;
  final bool done;

  const ImportState({
    this.tab = ImportTab.xtream,
    this.submitting = false,
    this.error,
    this.done = false,
  });

  ImportState copyWith({
    ImportTab? tab,
    bool? submitting,
    String? error,
    bool? done,
  }) {
    return ImportState(
      tab: tab ?? this.tab,
      submitting: submitting ?? this.submitting,
      error: error ?? this.error,
      done: done ?? this.done,
    );
  }

  @override
  List<Object?> get props => [tab, submitting, error, done];
}

// ── Cubit ──────────────────────────────────────────────────────────────────

class ImportCubit extends Cubit<ImportState> {
  final PlaylistRepository _playlists;
  final ContentRepository _content;
  final FlutterSecureStorage _storage;

  ImportCubit(
    this._playlists,
    this._content, {
    FlutterSecureStorage? secureStorage,
  })  : _storage = secureStorage ?? const FlutterSecureStorage(),
        super(const ImportState());

  void selectTab(ImportTab tab) =>
      emit(state.copyWith(tab: tab, error: null, done: false));

  Future<void> submit({
    required String name,
    String? serverUrl,
    String? username,
    String? password,
  }) async {
    emit(state.copyWith(submitting: true, error: null));

    final id =
        '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    final playlist = Playlist(
      id: id,
      name: name,
      type: _tabToType(state.tab),
      serverUrl: serverUrl,
      initial: initial,
    );

    // For xtream, write credentials to secure storage
    if (state.tab == ImportTab.xtream &&
        username != null &&
        password != null) {
      await _storage.write(key: 'xtream_user_$id', value: username);
      await _storage.write(key: 'xtream_pass_$id', value: password);
    }

    final importResult = await _content.importPlaylist(playlist);
    await importResult.when(
      ok: (_) async {
        final addResult = await _playlists.add(playlist);
        await addResult.when(
          ok: (_) async {
            await _playlists.setActive(playlist.id);
            emit(state.copyWith(submitting: false, done: true));
          },
          err: (f) async =>
              emit(state.copyWith(submitting: false, error: f.message)),
        );
      },
      err: (f) async =>
          emit(state.copyWith(submitting: false, error: f.message)),
    );
  }

  PlaylistType _tabToType(ImportTab tab) {
    switch (tab) {
      case ImportTab.xtream:
        return PlaylistType.xtream;
      case ImportTab.m3u:
        return PlaylistType.m3u;
      case ImportTab.upload:
        return PlaylistType.upload;
    }
  }
}
