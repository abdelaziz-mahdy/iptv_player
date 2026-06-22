import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noor_iptv/data/repositories/fakes/fake_repositories.dart';
import 'package:noor_iptv/features/import/cubit/import_cubit.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('ImportCubit', () {
    late FakePlaylistRepository playlists;
    late FakeContentRepository content;
    late MockSecureStorage storage;
    late ImportCubit cubit;

    setUp(() {
      playlists = FakePlaylistRepository();
      content = FakeContentRepository();
      storage = MockSecureStorage();

      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      cubit = ImportCubit(playlists, content, secureStorage: storage);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial state has xtream tab, not submitting, no error, not done',
        () {
      expect(cubit.state.tab, ImportTab.xtream);
      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.error, isNull);
      expect(cubit.state.done, isFalse);
    });

    test('selectTab(ImportTab.m3u) → state.tab == ImportTab.m3u', () {
      cubit.selectTab(ImportTab.m3u);
      expect(cubit.state.tab, ImportTab.m3u);
    });

    test(
        'submit with m3u tab: state.done == true and FakePlaylistRepository has 2 items',
        () async {
      cubit.selectTab(ImportTab.m3u);

      await cubit.submit(
        name: 'My',
        serverUrl: 'http://x/p.m3u',
      );

      expect(cubit.state.done, isTrue);
      expect(cubit.state.error, isNull);

      final result = await playlists.all();
      result.when(
        ok: (list) => expect(list.length, 2),
        err: (_) => fail('Expected Ok result'),
      );
    });
  });
}
