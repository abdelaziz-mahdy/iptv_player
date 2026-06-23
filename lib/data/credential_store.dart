/// Stores Xtream credentials. Abstracted so the app does not depend on the OS
/// keychain (unreliable on unsigned macOS builds: errors -34018, -25293).
abstract class CredentialStore {
  Future<void> save(
    String playlistId, {
    required String username,
    required String password,
  });

  Future<({String username, String password})?> read(String playlistId);
}

/// In-memory credential store backed by a plain [Map].
///
/// Default for tests and for [ImportCubit] / [DriftContentRepository] when no
/// store is injected. Does NOT persist across restarts — that is intentional
/// for unit tests so they stay hermetic.
class InMemoryCredentialStore implements CredentialStore {
  final _store = <String, ({String username, String password})>{};

  @override
  Future<void> save(
    String playlistId, {
    required String username,
    required String password,
  }) async {
    _store[playlistId] = (username: username, password: password);
  }

  @override
  Future<({String username, String password})?> read(String playlistId) async {
    return _store[playlistId];
  }
}
