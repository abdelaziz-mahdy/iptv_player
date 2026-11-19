import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/category_sidebar.dart';
import 'package:iptv_player/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

List<SidebarEntry> _entries({String? recent}) => [
  (id: '', label: 'All', count: 30),
  if (recent != null) (id: recent, label: 'Group $recent', count: 2),
  for (var i = 0; i < 30; i++) (id: 'g$i', label: 'Group g$i', count: 2),
];

Widget _wrap(List<SidebarEntry> entries, String? selected, int recentCount) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildTheme(
        palette: AppPalette.standard,
        hyperlegible: false,
        rtl: false,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 500,
            child: CategorySidebar(
              entries: entries,
              selectedId: selected,
              pinnedCount: 1 + recentCount,
              recentCount: recentCount,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('recent groups get a "Recent" heading', (tester) async {
    await tester.pumpWidget(_wrap(_entries(recent: 'g7'), 'g7', 1));
    await tester.pump();
    expect(find.text('RECENT'), findsOneWidget);
    // Listed twice: in Recent and in its normal place.
    expect(find.text('Group g7', skipOffstage: false), findsNWidgets(2));
  });

  testWidgets('no heading without recent groups', (tester) async {
    await tester.pumpWidget(_wrap(_entries(), null, 0));
    await tester.pump();
    expect(find.text('RECENT'), findsNothing);
  });

  testWidgets('the picked row stays put when it is added to Recent', (
    tester,
  ) async {
    // Scrolled down with "All" selected, the user picks g9: the selection
    // changes first, then the recency update arrives.
    await tester.pumpWidget(_wrap(_entries(), '', 0));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.text('Group g9')).dy;

    await tester.pumpWidget(_wrap(_entries(), 'g9', 0));
    await tester.pump();
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('Group g9')).dy,
      moreOrLessEquals(before, epsilon: 0.5),
      reason: 'selecting alone must not scroll',
    );

    // The recency update arrives: g9 is pinned above, rows shift down.
    await tester.pumpWidget(_wrap(_entries(recent: 'g9'), 'g9', 1));
    await tester.pump();
    await tester.pump();

    final tops = [
      for (final e in find.text('Group g9', skipOffstage: false).evaluate())
        if (e.renderObject case final RenderBox box when box.attached)
          box.localToGlobal(Offset.zero).dy,
    ];
    expect(
      tops,
      contains(moreOrLessEquals(before, epsilon: 0.5)),
      reason: 'the normal-place row did not move on screen',
    );
  });
}
