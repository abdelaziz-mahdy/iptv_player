import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/content_rail.dart';

void main() {
  testWidgets('renders title and items', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: const Scaffold(
        body: ContentRail(title: 'Trending', items: [Text('A'), Text('B')]),
      ),
    ));
    expect(find.text('Trending'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });
}
