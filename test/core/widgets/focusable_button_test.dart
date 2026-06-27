import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/focusable_button.dart';

void main() {
  testWidgets('invokes onPressed on tap and exposes semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: FocusableButton(
          semanticLabel: 'Play',
          onPressed: () => tapped = true,
          child: const Text('Play'),
        ),
      ),
    ));
    await tester.tap(find.text('Play'));
    expect(tapped, true);

    final node = tester.getSemantics(find.byType(FocusableButton));
    expect(node.label, contains('Play'));
    expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
    semantics.dispose();
  });

  testWidgets('invokes onPressed when Enter key is sent while focused',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: FocusableButton(
          autofocus: true,
          semanticLabel: 'Play',
          onPressed: () => pressed = true,
          child: const Text('Play'),
        ),
      ),
    ));
    await tester.pump();

    // Send Enter key — the FocusableActionDetector shortcut should fire onPressed
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(pressed, isTrue);
  });

  testWidgets('shows AnimatedScale with scale > 1.0 when focused and reduceMotion is false',
      (tester) async {
    // Force traditional (keyboard/D-pad) highlight mode so onShowFocusHighlight
    // fires in the test environment (the default is touch mode).
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic,
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: FocusableButton(
          autofocus: true,
          reduceMotion: false,
          semanticLabel: 'Test',
          onPressed: () {},
          child: const Text('Test'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, greaterThan(1.0));
  });

  testWidgets('AnimatedScale stays at 1.0 when focused but reduceMotion is true',
      (tester) async {
    // Even in traditional mode the scale must stay 1.0 when reduceMotion is true.
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic,
    );

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: FocusableButton(
          autofocus: true,
          reduceMotion: true,
          semanticLabel: 'Test',
          onPressed: () {},
          child: const Text('Test'),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, equals(1.0));
  });
}
