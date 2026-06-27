import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/di/injection.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/focusable_button.dart';
import 'package:iptv_player/features/playlists/playlists_screen.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';

import '../../support/fake_hydrated_storage.dart';

Widget _buildTestApp({VoidCallback? onAddPlaylist}) {
  return MaterialApp(
    theme: buildTheme(
      palette: AppPalette.standard,
      hyperlegible: false,
      rtl: false,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: PlaylistsScreen(
      onAddPlaylist: onAddPlaylist ?? () {},
      onSelected: (_) {},
    ),
  );
}

void main() {
  setUp(() async {
    installFakeHydratedStorage();
    await configureDependencies();
  });

  tearDown(() async => sl.reset());

  testWidgets(
      'PlaylistsScreen has at least one autofocused FocusableButton',
      (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    final autofocused = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    expect(autofocused, findsAtLeastNWidgets(1));
  });
}
