import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/a11y/accessibility_cubit.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/data/models/models.dart';
import 'package:noor_iptv/features/live/live_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

/// Pump the widget and let async work settle without waiting for running
/// animations (LiveBadge runs a repeating ticker that never ends).
Future<void> _pumpLive(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  // Allow microtasks and stream events to propagate.
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 100));
}

Widget _buildTestApp({void Function(Channel)? onPlayChannel}) {
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

  testWidgets('LiveScreen renders channel name from fakes', (tester) async {
    // Use a larger surface so the EPG grid doesn't clip aggressively.
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

  testWidgets('LiveScreen tapping channel info cell invokes onPlayChannel',
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

    // Tap the first visible channel cell area (find by text 'NOOR One').
    final channelCell = find.textContaining('NOOR One', skipOffstage: false);
    expect(channelCell, findsAtLeastNWidgets(1));
    await tester.tap(channelCell.first);
    await tester.pump(Duration.zero);

    expect(tappedChannel, isNotNull);
    expect(tappedChannel!.name, 'NOOR One');
  });
}
