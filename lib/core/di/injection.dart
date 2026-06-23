import 'package:get_it/get_it.dart';

import '../../data/credential_store.dart';
import '../../data/credential_store_drift.dart';
import '../../data/db/database.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/fakes/fake_repositories.dart';
import '../../data/repositories/repositories.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Registers app dependencies using in-memory fakes.
/// Used by widget tests and the DI test. Registers an [InMemoryCredentialStore]
/// so [ImportScreen] can resolve [CredentialStore] from the service locator.
Future<void> configureDependencies() async {
  sl.registerLazySingleton<CredentialStore>(InMemoryCredentialStore.new);
  sl.registerLazySingleton<PlaylistRepository>(FakePlaylistRepository.new);
  sl.registerLazySingleton<ContentRepository>(FakeContentRepository.new);
  sl.registerLazySingleton<EpgRepository>(FakeEpgRepository.new);
  sl.registerLazySingleton<PlaybackRepository>(FakePlaybackRepository.new);
}

/// Registers production dependencies backed by the real drift database.
/// Tests should continue using [configureDependencies] (fakes).
Future<void> configureProductionDependencies() async {
  final db = AppDatabase();
  sl.registerSingleton<AppDatabase>(db);

  final creds = DriftCredentialStore(db);
  sl.registerSingleton<CredentialStore>(creds);

  sl.registerLazySingleton<PlaylistRepository>(
      () => DriftPlaylistRepository(db));
  sl.registerLazySingleton<ContentRepository>(
      () => DriftContentRepository(db, credentialStore: creds));
  sl.registerLazySingleton<EpgRepository>(() => EpgRepositoryImpl(db));
  sl.registerLazySingleton<PlaybackRepository>(
      () => DriftPlaybackRepository(db));
}
