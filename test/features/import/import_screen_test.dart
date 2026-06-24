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

  testWidgets('server field is read-only (system IME cannot open)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final serverField = find.byKey(const ValueKey('import-server'));
    expect(serverField, findsOneWidget);

    // The EditableText inside the field must be readOnly
    final editable = tester.widget<EditableText>(
      find.descendant(of: serverField, matching: find.byType(EditableText)),
    );
    expect(editable.readOnly, isTrue,
        reason: 'Field must be read-only so the system IME never opens');
  });

  testWidgets(
      'tapping server field then keyboard keys updates server field text',
      (tester) async {
    // Use a tall viewport so the on-screen keyboard is fully visible.
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // 1. Tap the server field to make it the active keyboard target
    final serverField = find.byKey(const ValueKey('import-server'));
    await tester.tap(serverField);
    await tester.pump();

    // 2. Tap 'a' on the on-screen keyboard (lowercase layer, default)
    await tester.tap(find.text('a').first);
    await tester.pump();

    // 3. Switch to symbol layer and tap '1'
    await tester.tap(find.text('?123').first);
    await tester.pump();
    await tester.tap(find.text('1').first);
    await tester.pump();

    // 4. Assert the server field now shows 'a1'
    final editableAfter = tester.widget<EditableText>(
      find.descendant(of: serverField, matching: find.byType(EditableText)),
    );
    expect(editableAfter.controller.text, 'a1',
        reason: 'On-screen keyboard must append chars to the active field');
  });

  testWidgets(
      'field keeps focus across a rebuild (TV focus-loop regression — read-only variant)',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tap the server field to activate it (also focuses it).
    final serverField = find.byKey(const ValueKey('import-server'));
    expect(serverField, findsOneWidget);
    await tester.tap(serverField);
    await tester.pump();

    // The field's FocusNode should have focus
    EditableText editable() => tester.widget<EditableText>(
          find.descendant(of: serverField, matching: find.byType(EditableText)),
        );
    expect(editable().focusNode.hasFocus, isTrue,
        reason: 'field should hold focus after tapping it');

    // Trigger a rebuild via the password eye toggle — field must keep focus.
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(editable().focusNode.hasFocus, isTrue,
        reason: 'field must retain focus across an unrelated rebuild');
  });

  testWidgets('ImportScreen renders Import button', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(_l10n(tester).importAction), findsWidgets);
  });
}
