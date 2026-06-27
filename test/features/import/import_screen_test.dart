import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/features/import/import_screen.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ImportScreen)))!;

Widget _app() => MaterialApp(
      theme: buildTheme(
        palette: AppPalette.standard,
        hyperlegible: false,
        rtl: false,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ImportScreen(onImported: () {}),
    );

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('ImportScreen renders 3 tab buttons', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Xtream Codes'), findsOneWidget);
    expect(find.text('M3U URL'), findsOneWidget);
    expect(find.text(_l10n(tester).tabUpload), findsOneWidget);
  });

  testWidgets('ImportScreen renders Import button', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(_l10n(tester).importAction), findsWidgets);
  });

  testWidgets(
      'typing into the server field updates its controller (non-Android platform)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // On the test host (non-Android) the field is an editable TextFormField.
    final serverField = find.byKey(const ValueKey('import-server'));
    expect(serverField, findsOneWidget);

    await tester.enterText(serverField, 'http://example.com');
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: serverField, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, 'http://example.com');
  });
}
