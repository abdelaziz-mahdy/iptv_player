import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/features/import/import_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ImportScreen)))!;

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

    // Xtream Codes and M3U URL are proper nouns — kept as English literals
    expect(find.text('Xtream Codes'), findsOneWidget);
    expect(find.text('M3U URL'), findsOneWidget);
    // "File" tab is now localized — look up tabUpload
    expect(find.text(_l10n(tester).tabUpload), findsOneWidget);
  });

  testWidgets('ImportScreen renders Import button', (tester) async {
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

    // The submit button now shows importAction key
    expect(find.text(_l10n(tester).importAction), findsWidgets);
  });
}
