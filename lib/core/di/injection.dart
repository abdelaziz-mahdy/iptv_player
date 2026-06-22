import 'package:get_it/get_it.dart';
import '../../data/db/database.dart';
import '../../data/repositories/drift_repositories.dart';
import '../../data/repositories/fakes/fake_repositories.dart';
import '../../data/repositories/repositories.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Registers app dependencies. For now this wires the in-memory fakes against
/// the repository contracts; the Data & Import plan swaps these for the real
/// drift-backed implementations without touching the feature layer.
Future<void> configureDependencies() async {
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
  sl.registerLazySingleton<PlaylistRepository>(
      () => DriftPlaylistRepository(db));
  sl.registerLazySingleton<ContentRepository>(
      () => DriftContentRepository(db));
  sl.registerLazySingleton<EpgRepository>(() => EpgRepositoryImpl(db));
  sl.registerLazySingleton<PlaybackRepository>(
      () => DriftPlaybackRepository(db));
}
