import 'package:iptv_player/core/logging/app_logger.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/credential_store.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

// ── State ──────────────────────────────────────────────────────────────────

enum ImportTab { xtream, m3u, upload }

/// Why an import failed, so the screen can say something more useful than
/// "Failed to import playlist" — which was all the user ever saw, whatever
/// went wrong.
enum ImportFailure {
  /// Nothing is listening. Overwhelmingly this is `https://` against a panel
  /// that only serves plain HTTP, which is the common shape for Xtream
  /// providers.
  connectionRefused,

  /// Host does not resolve — usually a typo in the address.
  dns,

  /// Reached the server, but it did not answer in time.
  timeout,

  /// The server answered and rejected the credentials.
  credentials,

  /// Anything else.
  unknown,
}

class ImportState extends Equatable {
  final ImportTab tab;
  final bool submitting;
  final String? error;
  final ImportFailure? failure;
  final bool done;

  const ImportState({
    this.tab = ImportTab.xtream,
    this.submitting = false,
    this.error,
    this.failure,
    this.done = false,
  });

  static const _absent = Object();

  ImportState copyWith({
    ImportTab? tab,
    bool? submitting,
    Object? error = _absent,
    Object? failure = _absent,
    bool? done,
  }) {
    return ImportState(
      tab: tab ?? this.tab,
      submitting: submitting ?? this.submitting,
      error: error == _absent ? this.error : error as String?,
      failure:
          failure == _absent ? this.failure : failure as ImportFailure?,
      done: done ?? this.done,
    );
  }

  @override
  List<Object?> get props => [tab, submitting, error, failure, done];
}

// ── Cubit ──────────────────────────────────────────────────────────────────

class ImportCubit extends Cubit<ImportState> {
  final PlaylistRepository _playlists;
  final ContentRepository _content;
  final CredentialStore _credentials;

  ImportCubit(
    this._playlists,
    this._content, {
    CredentialStore? credentialStore,
  })  : _credentials = credentialStore ?? InMemoryCredentialStore(),
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

    try {
      // For xtream, write credentials to the credential store.
      if (state.tab == ImportTab.xtream &&
          username != null &&
          password != null) {
        await _credentials.save(id, username: username, password: password);
      }

      appLog.info('import start type=${playlist.type.name} '
          'server=${scrubUrl(serverUrl ?? '-')}');

      final importResult = await _content.importPlaylist(playlist);
      await importResult.when(
        ok: (_) async {
          final addResult = await _playlists.add(playlist);
          await addResult.when(
            ok: (_) async {
              await _playlists.setActive(playlist.id);
              appLog.info('import ok id=$id');
              emit(state.copyWith(submitting: false, done: true));
            },
            err: (f) async {
              appLog.error('import failed saving playlist: ${f.message}');
              emit(state.copyWith(submitting: false, error: f.message));
            },
          );
        },
        err: (f) async {
          // The user only ever saw "failed to import"; without this the reason
          // was gone the moment the snackbar closed.
          appLog.error('import failed fetching playlist: ${f.message} '
              'cause=${f.cause}');
          emit(state.copyWith(
            submitting: false,
            error: f.message,
            failure: classify(f.cause),
          ));
        },
      );
    } catch (e, st) {
      // Surface platform errors as a friendly message.
      appLog.handle(e, st, 'import threw');
      emit(state.copyWith(
        submitting: false,
        error: 'Could not save the playlist: $e',
        failure: classify(e),
      ));
    }
  }

  /// Maps the exception carried on a [Failure] to something the screen can
  /// explain. The strings come from dart:io / package:http rather than a typed
  /// error, so matching on them is the only option available.
  static ImportFailure classify(Object? cause) {
    final text = cause?.toString().toLowerCase() ?? '';
    if (text.contains('connection refused')) {
      return ImportFailure.connectionRefused;
    }
    if (text.contains('failed host lookup') ||
        text.contains('nodename nor servname') ||
        text.contains('no address associated')) {
      return ImportFailure.dns;
    }
    if (text.contains('timed out') || text.contains('timeout')) {
      return ImportFailure.timeout;
    }
    if (text.contains('401') ||
        text.contains('403') ||
        text.contains('unauthor')) {
      return ImportFailure.credentials;
    }
    return ImportFailure.unknown;
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
