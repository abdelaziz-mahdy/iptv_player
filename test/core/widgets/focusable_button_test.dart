import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';

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
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    semantics.dispose();
  });
}
