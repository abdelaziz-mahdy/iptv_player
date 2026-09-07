// Screenshot tour: renders the real app against demo data and writes PNGs.
//
//   tools/screenshot_tour.sh
//
// Everything on screen is fictional — generated gradient artwork and invented
// titles — so the images can go in a public README without exposing a real
// provider's catalog, which is the whole reason this exists rather than just
// photographing the app on the TV.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptv_player/app.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/data/repositories/repositories.dart';

import 'demo_data.dart';

/// In-memory [Storage] so the HydratedCubits (locale, accessibility) do not
/// touch disk and every run starts from the same defaults.
class _MemStorage implements Storage {
  final _m = <String, dynamic>{};
  @override
  dynamic read(String key) => _m[key];
  @override
  Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
  @override
  Future<void> close() async => _m.clear();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const outDir = String.fromEnvironment('SHOT_DIR', defaultValue: 'docs/screenshots');
  final boundaryKey = GlobalKey();

  // Pinned so runs are comparable: pumpWidget applies tight constraints from
  // the test surface, so a SizedBox alone would capture whatever size the host
  // window happened to be.
  //
  // Three profiles because AdaptiveShell switches chrome at
  // NoorBreakpoints.rail = 700 — a NavigationRail above it, a NavigationBar
  // below. Shooting only one width would leave half the app undocumented.
  const profiles = <({String name, Size size})>[
    (name: 'tv', size: Size(1920, 1080)),
    (name: 'desktop', size: Size(1440, 900)),
    (name: 'phone', size: Size(412, 915)),
  ];

  void setSurface(Size s) {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = s * 2;
    view.devicePixelRatio = 2;
  }

  setUp(() async {
    HydratedBloc.storage = _MemStorage();
    await configureDependencies();
    // Swap the sparse unit-test fake for a catalog worth photographing.
    await sl.unregister<ContentRepository>();
    sl.registerLazySingleton<ContentRepository>(DemoContentRepository.new);
  });

  tearDown(() async {
    await sl.reset();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> shoot(String name) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$outDir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('[SHOT] $outDir/$name.png');
  }

  Widget frame(Size size) => RepaintBoundary(
        key: boundaryKey,
        child: SizedBox.fromSize(size: size, child: const NoorApp()),
      );

  // Bounded pumps only: the app runs repeating timers (sync service, bitrate
  // polling), so pumpAndSettle would never return.
  Future<void> settle(WidgetTester t, [int ms = 1200]) async {
    for (var i = 0; i < 6; i++) {
      await t.pump(Duration(milliseconds: ms ~/ 6));
    }
  }

  Future<void> openTab(WidgetTester t, String label) async {
    final dest = find.text(label);
    if (dest.evaluate().isEmpty) {
      // ignore: avoid_print
      print('[SHOT] tab "$label" not found — skipping');
      return;
    }
    await t.tap(dest.first, warnIfMissed: false);
    await settle(t);
  }

  /// On phone widths Live/Movies/Series open on a category list and the poster
  /// grid is a level down, so without this the narrow shots would only ever
  /// show a list of category names. Tapping "All" on a wide layout just
  /// reselects the category already showing, so it is safe either way.
  Future<void> drillIntoAll(WidgetTester t) async {
    final all = find.text('All');
    if (all.evaluate().isEmpty) return;
    await t.tap(all.first, warnIfMissed: false);
    await settle(t);
  }

  for (final profile in profiles) {
    testWidgets('tour ${profile.name}', (t) async {
      setSurface(profile.size);
      await t.pumpWidget(frame(profile.size));
      await settle(t, 2500);
      await shoot('${profile.name}/01-home');

      for (final (label, name, drill) in const [
        ('Live TV', '02-live', true),
        ('Movies', '03-movies', true),
        ('Series', '04-series', true),
        ('Favorites', '05-favorites', false),
        ('Search', '06-search', false),
      ]) {
        await openTab(t, label);
        if (drill) await drillIntoAll(t);
        await shoot('${profile.name}/$name');
      }
    });
  }
}
