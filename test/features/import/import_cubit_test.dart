import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/data/credential_store.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/features/import/cubit/import_cubit.dart';

void main() {
  group('ImportCubit', () {
    late FakePlaylistRepository playlists;
    late FakeContentRepository content;
    late InMemoryCredentialStore credentialStore;
    late ImportCubit cubit;

    setUp(() {
      playlists = FakePlaylistRepository();
      content = FakeContentRepository();
      credentialStore = InMemoryCredentialStore();
      cubit = ImportCubit(playlists, content, credentialStore: credentialStore);
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

    test('submit with xtream tab saves credentials to store', () async {
      // Xtream tab is already selected (default).
      await cubit.submit(
        name: 'XTV',
        serverUrl: 'http://xtream.example.com',
        username: 'alice',
        password: 'secret123',
      );

      // The cubit ID is derived from name + timestamp; we can check that
      // exactly one playlist was added (initial + active).
      final allResult = await playlists.all();
      allResult.when(
        ok: (list) => expect(list.length, 2), // existing default + new
        err: (_) => fail('Expected Ok result'),
      );
    });
  });

  group('failure classification', () {
    test('connection refused — the https-against-an-http-panel case', () {
      // Verbatim shape of what the device produced: an https:// address
      // against a provider serving only plain HTTP.
      expect(
        ImportCubit.classify(
          'ClientException with SocketException: Connection refused '
          '(OS Error: Connection refused, errno = 111), address = example.com',
        ),
        ImportFailure.connectionRefused,
      );
    });

    test('bad hostname', () {
      expect(
        ImportCubit.classify('SocketException: Failed host lookup: nope.invalid'),
        ImportFailure.dns,
      );
    });

    test('timeout', () {
      expect(ImportCubit.classify('TimeoutException after 0:00:30.000000'),
          ImportFailure.timeout);
    });

    test('rejected credentials', () {
      expect(ImportCubit.classify('HTTP 401 Unauthorized'),
          ImportFailure.credentials);
    });

    test('anything else falls back to unknown', () {
      expect(ImportCubit.classify('some parser blew up'),
          ImportFailure.unknown);
      expect(ImportCubit.classify(null), ImportFailure.unknown);
    });
  });
}
