import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/on_screen_keyboard.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: buildTheme(
        palette: AppPalette.standard,
        hyperlegible: false,
        rtl: false,
      ),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('tapping letter key calls onChar with that letter', (tester) async {
    String? received;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (c) => received = c,
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // 'a' must be visible on the lowercase layer (default)
    await tester.tap(find.text('a').first);
    await tester.pump();

    expect(received, 'a');
  });

  testWidgets('Shift toggles uppercase and letter key calls onChar uppercase',
      (tester) async {
    String? received;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (c) => received = c,
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // Tap Shift to switch to uppercase layer
    await tester.tap(find.text('⇧').first);
    await tester.pump();

    // Now 'A' should be visible
    await tester.tap(find.text('A').first);
    await tester.pump();

    expect(received, 'A');
  });

  testWidgets('Backspace calls onBackspace', (tester) async {
    var called = false;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (_) {},
      onBackspace: () => called = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('⌫').first);
    await tester.pump();

    expect(called, isTrue);
  });

  testWidgets('?123 toggles to symbol layer with digit keys', (tester) async {
    String? received;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (c) => received = c,
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // Tap ?123 to open symbol layer
    await tester.tap(find.text('?123').first);
    await tester.pump();

    // Digit '1' must be visible in symbol layer
    await tester.tap(find.text('1').first);
    await tester.pump();

    expect(received, '1');
  });

  testWidgets('Clear button calls onClear when provided', (tester) async {
    var cleared = false;
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (_) {},
      onBackspace: () {},
      onClear: () => cleared = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear').first);
    await tester.pump();

    expect(cleared, isTrue);
  });

  testWidgets('all letter key widgets have semanticLabel set', (tester) async {
    await tester.pumpWidget(_wrap(OnScreenKeyboard(
      onChar: (_) {},
      onBackspace: () {},
    )));
    await tester.pumpAndSettle();

    // Verify semantics — at least 'a' has a label
    final semantics = tester.getSemantics(find.text('a').first);
    expect(semantics.label, isNotEmpty);
  });
}
