import 'db/database.dart';
import 'db/tables.dart';
import 'credential_store.dart';

/// [CredentialStore] backed by the app's drift SQLite database.
///
/// Credentials are stored in the [XtreamCredentials] table (schema v2).
/// Works on all platforms including unsigned macOS builds — no OS keychain
/// entitlements required.
class DriftCredentialStore implements CredentialStore {
  DriftCredentialStore(this._db);

  final AppDatabase _db;

  @override
  Future<void> save(
    String playlistId, {
    required String username,
    required String password,
  }) async {
    await _db.upsertCredentials(
      XtreamCredentialsCompanion.insert(
        playlistId: playlistId,
        username: username,
        password: password,
      ),
    );
  }

  @override
  Future<({String username, String password})?> read(String playlistId) async {
    final row = await _db.getCredentials(playlistId);
    if (row == null) return null;
    return (username: row.username, password: row.password);
  }
}
