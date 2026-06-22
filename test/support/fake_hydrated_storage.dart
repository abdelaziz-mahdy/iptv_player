import 'package:hydrated_bloc/hydrated_bloc.dart';

/// In-memory [Storage] for testing `HydratedCubit`s without touching disk.
///
/// Call [installFakeHydratedStorage] in `setUp` to reset state per test.
class FakeHydratedStorage implements Storage {
  final _map = <String, dynamic>{};

  @override
  dynamic read(String key) => _map[key];

  @override
  Future<void> write(String key, dynamic value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);

  @override
  Future<void> clear() async => _map.clear();

  @override
  Future<void> close() async => _map.clear();
}

void installFakeHydratedStorage() {
  HydratedBloc.storage = FakeHydratedStorage();
}
