import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/core/theme/app_palette.dart';
import 'package:iptv_player/core/theme/app_theme.dart';
import 'package:iptv_player/core/widgets/focusable_button.dart';
import 'package:iptv_player/core/widgets/poster_card.dart';

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

  testWidgets('no heart icon when onToggleFavorite is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: const Scaffold(
        body: PosterCard(
          title: 'Dune',
          onTap: null,
        ),
      ),
    ));
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('heart button is shown when onToggleFavorite is provided', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: PosterCard(
          title: 'Dune',
          onTap: () {},
          onToggleFavorite: () {},
        ),
      ),
    ));
    // Should show unfilled heart (not favorite)
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
  });

  testWidgets('shows filled heart when isFavorite is true', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: PosterCard(
          title: 'Dune',
          onTap: () {},
          isFavorite: true,
          onToggleFavorite: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('tapping heart invokes onToggleFavorite and NOT onTap', (tester) async {
    var tapped = false;
    var heartTapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: PosterCard(
          title: 'Dune',
          onTap: () => tapped = true,
          onToggleFavorite: () => heartTapped = true,
        ),
      ),
    ));

    // Tap the heart icon button
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();

    expect(heartTapped, isTrue);
    expect(tapped, isFalse);
  });

  testWidgets('tapping card still fires onTap when heart is present', (tester) async {
    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: PosterCard(
          title: 'Dune',
          onTap: () => tapped = true,
          onToggleFavorite: () {},
        ),
      ),
    ));

    // Tap the card title (not the heart)
    await tester.tap(find.text('Dune'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('heart has Semantics label for accessibility', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: PosterCard(
          title: 'Dune',
          onTap: () {},
          onToggleFavorite: () {},
        ),
      ),
    ));

    // Verify a semantics label exists for the favorite button
    expect(
      find.bySemanticsLabel(RegExp(r'[Ff]av')),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('heart is NOT a focus stop (read-only during D-pad navigation)',
      (tester) async {
    var heartActivated = false;
    var cardTapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
      home: Scaffold(
        body: PosterCard(
          title: 'Dune',
          onTap: () => cardTapped = true,
          onToggleFavorite: () => heartActivated = true,
        ),
      ),
    ));

    // Only the card itself is a FocusableButton — the heart must not add a
    // second focus stop, so D-pad grid navigation skips over it.
    expect(find.byType(FocusableButton), findsOneWidget);

    // It still carries its own button semantics for screen readers / touch.
    expect(
      find.bySemanticsLabel(RegExp(r'[Ff]avorites')),
      findsAtLeastNWidgets(1),
    );

    // Tapping it still toggles favorite and does NOT fire the card's onTap.
    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pump();
    expect(heartActivated, isTrue);
    expect(cardTapped, isFalse);
  });
}
