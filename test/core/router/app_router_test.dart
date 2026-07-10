import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/core/router/app_router.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

void main() {
  group('PlayerArgs queue navigation', () {
    final queue = [
      const PlayerQueueItem(
          itemKey: 'episode:s1:ep:1', url: 'u1', title: 'E1',
          recentKey: 'series:s1'),
      const PlayerQueueItem(
          itemKey: 'episode:s1:ep:2', url: 'u2', title: 'E2',
          recentKey: 'series:s1'),
      const PlayerQueueItem(
          itemKey: 'episode:s1:ep:3', url: 'u3', title: 'E3',
          recentKey: 'series:s1'),
    ];

    PlayerArgs argsAt(int i) => PlayerArgs(
          itemKey: queue[i].itemKey,
          url: queue[i].url,
          title: queue[i].title,
          kind: MediaKind.episode,
          playlistId: 'p1',
          recentKey: queue[i].recentKey,
          queue: queue,
          queueIndex: i,
        );

    test('atQueueIndex carries item fields, shared kind/playlist and queue', () {
      final next = argsAt(0).atQueueIndex(1);
      expect(next.itemKey, 'episode:s1:ep:2');
      expect(next.url, 'u2');
      expect(next.title, 'E2');
      expect(next.recentKey, 'series:s1');
      expect(next.kind, MediaKind.episode);
      expect(next.playlistId, 'p1');
      expect(next.queueIndex, 1);
      expect(next.queue, same(queue));
    });

    test('middle item has both a previous and a next neighbour', () {
      final a = argsAt(1);
      expect(a.queueIndex > 0, isTrue); // previous available
      expect(a.queueIndex < a.queue!.length - 1, isTrue); // next available
    });

    test('first item has no previous; last item has no next (stop at ends)', () {
      final first = argsAt(0);
      expect(first.queueIndex > 0, isFalse);
      expect(first.queueIndex < first.queue!.length - 1, isTrue);

      final last = argsAt(2);
      expect(last.queueIndex > 0, isTrue);
      expect(last.queueIndex < last.queue!.length - 1, isFalse);
    });
  });

  setUp(() async {
    installFakeHydratedStorage();
    await sl.reset();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('home branch renders inside the shell', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
  });
}
