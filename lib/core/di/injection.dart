import 'package:get_it/get_it.dart';
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
