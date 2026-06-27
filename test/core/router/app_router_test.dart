import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/core/router/app_router.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

void main() {
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
