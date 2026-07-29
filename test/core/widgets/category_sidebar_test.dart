import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/category_sidebar.dart';

void main() {
  Widget host({
    required List<SidebarEntry> entries,
    String? selectedId,
    int pinnedCount = 0,
    ValueChanged<String>? onSelect,
  }) {
    return MaterialApp(
      theme: buildTheme(
          palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: CategorySidebar(
          entries: entries,
          selectedId: selectedId,
          pinnedCount: pinnedCount,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );
  }

  const entries = <SidebarEntry>[
    (id: '', label: 'All', count: 12),
    (id: 'sport', label: 'Sports', count: 4),
    (id: 'news', label: 'News', count: 8),
  ];

  testWidgets('renders every entry with its count', (tester) async {
    await tester.pumpWidget(host(entries: entries));

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('draws one separator, at the pinned boundary', (tester) async {
    await tester.pumpWidget(host(entries: entries, pinnedCount: 2));
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('no separator when the pinned block is everything',
      (tester) async {
    await tester.pumpWidget(host(entries: entries, pinnedCount: 0));
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('focus starts on the selected row, not the first', (tester) async {
    await tester.pumpWidget(host(entries: entries, selectedId: 'news'));
    await tester.pump();

    // The focused subtree is the one containing the selected label.
    final focused = find.ancestor(
      of: find.text('News'),
      matching: find.byType(Focus),
    );
    expect(focused, findsWidgets);
    expect(
      tester
          .widgetList<Focus>(focused)
          .any((f) => f.focusNode?.hasFocus ?? false),
      isTrue,
    );
  });

  testWidgets('reports the tapped entry id', (tester) async {
    String? picked;
    await tester.pumpWidget(
      host(entries: entries, onSelect: (id) => picked = id),
    );
    await tester.tap(find.text('Sports'));
    expect(picked, 'sport');
  });
}
