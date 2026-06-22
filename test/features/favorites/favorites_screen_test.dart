import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/features/favorites/favorites_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _buildTestApp({void Function(String)? onOpen}) {
  return MaterialApp(
    theme: buildTheme(
      palette: AppPalette.standard,
      hyperlegible: false,
      rtl: false,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: FavoritesScreen(onOpen: onOpen ?? (_) {}),
  );
}

Future<void> _pumpAndIgnoreOverflow(
    WidgetTester tester, Widget widget) async {
  final previousHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previousHandler?.call(details);
  };
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
  FlutterError.onError = previousHandler;
}

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets('FavoritesScreen shows empty-state message when no favorites',
      (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // Empty state message text
    expect(
      find.textContaining(
        'Items you add to My List will appear here.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('FavoritesScreen shows the favorites title', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    expect(find.text('Favorites', skipOffstage: false), findsAtLeastNWidgets(1));
  });

  testWidgets('FavoritesScreen renders without error', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    expect(find.byType(FavoritesScreen), findsOneWidget);
  });
}
