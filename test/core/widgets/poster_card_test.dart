import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/poster_card.dart';

void main() {
  testWidgets('shows title, badge, and is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: PosterCard(
          title: 'Dune',
          subtitle: '2021',
          badge: 'HD',
          imageUrl: null,
          progress: 0.4,
          onTap: () => tapped = true,
        ),
      ),
    ));
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('HD'), findsOneWidget);
    await tester.tap(find.text('Dune'));
    expect(tapped, true);
  });
}
