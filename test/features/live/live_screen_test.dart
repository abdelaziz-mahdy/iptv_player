import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/a11y/accessibility_cubit.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/focusable_button.dart';
import 'package:iptv_player/data/models/models.dart';
import 'package:iptv_player/data/repositories/fakes/fake_repositories.dart';
import 'package:iptv_player/data/repositories/repositories.dart';
import 'package:iptv_player/features/live/channel_list_screen.dart';
import 'package:iptv_player/features/live/cubit/live_cubit.dart';
import 'package:iptv_player/features/live/live_screen.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

// ---------------------------------------------------------------------------
// A minimal content repository with two categorised channels so we can test
// the narrow-layout drill-in with a non-"All" group.
// ---------------------------------------------------------------------------
class _CategorisedContentRepository extends FakeContentRepository {
  static const _pid = 'p1';

  // One channel in 'sports' category, one in 'news'.
  final _channels = [
    const Channel(
      id: 'ch-sports',
      playlistId: _pid,
      name: 'Sports Channel',
      number: '201',
      streamUrl: 'http://x/s1',
      categoryId: 'cat-sports',
    ),
    const Channel(
      id: 'ch-news',
      playlistId: _pid,
      name: 'News Channel',
      number: '202',
      streamUrl: 'http://x/n1',
      categoryId: 'cat-news',
    ),
  ];

  @override
  Stream<List<Channel>> channels(String playlistId) => Stream.value(_channels);

  @override
  Future<List<CategoryRef>> categories(
      String playlistId, MediaKind kind) async {
    if (kind != MediaKind.channel) return const [];
    return const [
      CategoryRef(id: 'cat-sports', name: 'Sports'),
      CategoryRef(id: 'cat-news', name: 'News'),
    ];
  }
}

/// Builds a narrow (phone) app that creates a [LiveCubit] backed by the
/// supplied [contentRepo], so we can inject a custom content repository.
Widget _buildNarrowAppWithRepo(
  ContentRepository contentRepo, {
  void Function(Channel)? onPlayChannel,
}) {
  return BlocProvider<AccessibilityCubit>(
    create: (_) => AccessibilityCubit(),
    child: BlocProvider<LiveCubit>(
      create: (_) => LiveCubit(contentRepo, FakePlaylistRepository())..load(),
      child: MaterialApp(
        theme: buildTheme(
          palette: AppPalette.standard,
          hyperlegible: false,
          rtl: false,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Build _LiveView directly so we can supply our own cubit.
        home: _LiveViewForTest(onPlayChannel: onPlayChannel ?? (_) {}),
      ),
    ),
  );
}

/// Mirrors _LiveView from live_screen.dart but reads the cubit from the
/// inherited BlocProvider instead of creating a new one.
class _LiveViewForTest extends StatelessWidget {
  const _LiveViewForTest({required this.onPlayChannel});
  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveCubit, LiveState>(
      builder: (context, state) {
        if (state.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.groups.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('No channels')),
          );
        }
        // Always use narrow layout in this test harness.
        return Scaffold(
          body: _NarrowLayoutForTest(onPlayChannel: onPlayChannel),
        );
      },
    );
  }
}

/// Exposes the private _NarrowLayout logic via a public test-only widget.
/// We reproduce the exact logic from _NarrowLayout to keep the test isolated
/// from private Flutter internals; any divergence here is intentional.
class _NarrowLayoutForTest extends StatelessWidget {
  const _NarrowLayoutForTest({required this.onPlayChannel});
  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveCubit, LiveState>(
      builder: (context, state) {
        return ListView.builder(
          itemCount: state.groups.length,
          itemBuilder: (context, index) {
            final group = state.groups[index];
            return ListTile(
              title: Text(group.name),
              onTap: () {
                final cubit = context.read<LiveCubit>();
                cubit.selectGroup(group.id);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChannelListScreen(
                      groupName: group.name,
                      channels: cubit.state.channelsInGroup,
                      onPlayChannel: onPlayChannel,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Pump the widget and let async work settle without waiting for running
/// animations (LiveBadge runs a repeating ticker that never ends).
Future<void> _pumpLive(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  // Allow microtasks and stream events to propagate.
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _buildTestApp({
  void Function(Channel)? onPlayChannel,
}) {
  return BlocProvider(
    create: (_) => AccessibilityCubit(),
    child: MaterialApp(
      theme: buildTheme(
        palette: AppPalette.standard,
        hyperlegible: false,
        rtl: false,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LiveScreen(onPlayChannel: onPlayChannel ?? (_) {}),
    ),
  );
}

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  // -------------------------------------------------------------------------
  // Wide layout (>= 700 px wide) — sidebar + grid
  // -------------------------------------------------------------------------

  testWidgets('LiveScreen renders channel name from fakes (wide)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLive(tester, _buildTestApp());

    // FakeContentRepository seeds: 'NOOR One', 'NOOR Sports', 'NOOR News'
    expect(
      find.textContaining('NOOR One', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('LiveScreen shows Live TV app bar title', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLive(tester, _buildTestApp());

    expect(
      find.text('Live TV', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('LiveScreen shows group label "All" (wide)', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLive(tester, _buildTestApp());

    expect(
      find.text('All', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('LiveScreen tapping channel tile invokes onPlayChannel (wide)',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Channel? tappedChannel;
    await _pumpLive(
      tester,
      _buildTestApp(onPlayChannel: (ch) => tappedChannel = ch),
    );

    // Tap the first visible channel tile (find by text 'NOOR One').
    final channelTile = find.textContaining('NOOR One', skipOffstage: false);
    expect(channelTile, findsAtLeastNWidgets(1));
    await tester.tap(channelTile.first);
    await tester.pump(Duration.zero);

    expect(tappedChannel, isNotNull);
    expect(tappedChannel!.name, 'NOOR One');
  });

  // -------------------------------------------------------------------------
  // Narrow layout (< 700 px wide) — group list only
  // -------------------------------------------------------------------------

  testWidgets('LiveScreen shows group list on narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLive(tester, _buildTestApp());

    // Should show group names, not individual channel tiles in grid
    expect(
      find.text('All', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets(
      'LiveScreen narrow: tapping a group navigates to ChannelListScreen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLive(tester, _buildTestApp());

    // Tap the 'All' group
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    // ChannelListScreen should be pushed — check that a channel name appears
    expect(
      find.textContaining('NOOR', skipOffstage: false),
      findsAtLeastNWidgets(1),
    );
  });

  // -------------------------------------------------------------------------
  // Narrow layout drill-in: non-"All" group shows only that group's channels
  // -------------------------------------------------------------------------

  testWidgets(
      'Narrow drill-in: tapping "Sports" group pushes ChannelListScreen '
      'with only the Sports channel (not channels from other groups)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build a cubit backed by our categorised-channel fake.
    // Create the cubit inside BlocProvider (via _buildNarrowAppWithRepo) so
    // that async work runs within the test's fake-async zone, avoiding
    // pumpAndSettle hanging on never-closing broadcast streams.
    final contentRepo = _CategorisedContentRepository();
    final app = _buildNarrowAppWithRepo(contentRepo);
    await tester.pumpWidget(app);
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 100));

    // The group list should contain "Sports" and "News" (plus "All").
    expect(find.text('Sports', skipOffstage: false), findsAtLeastNWidgets(1));

    // Tap the "Sports" group tile.
    await tester.tap(find.text('Sports').first);
    // Pump through the navigation animation (300 ms slide + fade) without
    // using pumpAndSettle, which can hang when background Dart streams
    // (e.g. FakePlaylistRepository's broadcast controller) keep the event
    // loop alive indefinitely.
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 350));

    // After navigation, ChannelListScreen must show only the Sports channel.
    expect(
      find.text('Sports Channel', skipOffstage: false),
      findsAtLeastNWidgets(1),
      reason: 'Sports channel must appear after tapping Sports group',
    );
    expect(
      find.text('News Channel', skipOffstage: false),
      findsNothing,
      reason: 'News channel must NOT appear — it is in a different group',
    );

    // Verify the pushed screen received exactly the cubit's channelsInGroup
    // for the Sports group (one channel).
    expect(
      tester.widgetList<ChannelListScreen>(find.byType(ChannelListScreen)),
      isNotEmpty,
      reason: 'ChannelListScreen should be on the navigation stack',
    );
    final screen = tester.widget<ChannelListScreen>(
      find.byType(ChannelListScreen),
    );
    expect(screen.channels, hasLength(1));
    expect(screen.channels.first.name, 'Sports Channel');
  });

  testWidgets(
      'LiveScreen has at least one autofocused FocusableButton when content loads',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLive(tester, _buildTestApp());

    final autofocused = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    expect(autofocused, findsAtLeastNWidgets(1));
  });
}
