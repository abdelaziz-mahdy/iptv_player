import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/features/import/import_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('ImportScreen renders 3 tab buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          palette: AppPalette.standard,
          hyperlegible: false,
          rtl: false,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportScreen(onImported: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xtream Codes'), findsOneWidget);
    expect(find.text('M3U URL'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
  });

  testWidgets('ImportScreen renders Add Playlist button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          palette: AppPalette.standard,
          hyperlegible: false,
          rtl: false,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ImportScreen(onImported: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Playlist'), findsWidgets);
  });
}
