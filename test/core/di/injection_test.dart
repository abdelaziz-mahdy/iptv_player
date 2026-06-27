import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/data/repositories/repositories.dart';

void main() {
  test('repositories resolve from the container', () async {
    await configureDependencies();
    expect(sl<ContentRepository>(), isNotNull);
    expect(sl<PlaylistRepository>(), isNotNull);
    expect(sl<EpgRepository>(), isNotNull);
    expect(sl<PlaybackRepository>(), isNotNull);
    await sl.reset();
  });
}
