import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/router/app_router.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('home branch renders inside the shell', (tester) async {
    final router = buildRouter();
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsWidgets);
  });
}
