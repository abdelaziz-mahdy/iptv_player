import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/adaptive_shell.dart';

Widget _wrap(Size size) => MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: AdaptiveShell(
          brand: 'NOOR',
          currentIndex: 0,
          onSelect: (_) {},
          destinations: const [
            NavDestinationData(Icons.home, 'Home'),
            NavDestinationData(Icons.tv, 'Live'),
          ],
          body: const Text('BODY'),
        ),
      ),
    );

void main() {
  testWidgets('wide layout uses NavigationRail', (tester) async {
    await tester.pumpWidget(_wrap(const Size(1280, 800)));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('narrow layout uses NavigationBar', (tester) async {
    await tester.pumpWidget(_wrap(const Size(400, 800)));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
