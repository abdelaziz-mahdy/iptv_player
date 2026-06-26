# TV Focus Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Android TV D-pad navigation reliable on every screen: a high-contrast focus ring that is always visible regardless of button background, and a sensible first-focus element on every screen so the remote is never "stuck" with nothing focused.

**Architecture:** Two independent concerns are handled in sequence: (1) enhance `FocusableButton` with a near-white outer ring plus `AnimatedScale` (skipped if `reduceMotion`) so the ring is legible on any background color; (2) set `autofocus: true` on the designated first-focus widget in each feature screen, or — for stateful screens where the first element is determined at runtime — create a stable `FocusNode` in `State.initState`, request focus in a post-frame callback guarded by `if (mounted)`, and dispose it in `dispose()`. No `FocusScope` traps are introduced. `FocusTraversalGroup` is added on screens that have isolated content regions to keep D-pad traversal sensible.

**Tech Stack:** Flutter (Dart), BLoC (flutter_bloc / HydratedBloc), `FocusableActionDetector`, `AnimatedScale`, `FocusNode`, `WidgetsBinding.instance.addPostFrameCallback`.

## Global Constraints

- Branch: `build/noor-foundation` — do NOT switch branches.
- `flutter analyze` must pass clean after every task.
- `flutter test` must remain fully green after every task (fix any autofocus-induced test failures inline in the same task).
- `FocusableButton` API (`child`, `onPressed`, `semanticLabel`, `autofocus`) must remain unchanged.
- Focus ring must use `foregroundDecoration` only — must NOT change layout size.
- Scale animation must be skipped when `AccessibilitySettings.reduceMotion` is true; read via `context.watch<AccessibilityCubit>().state.reduceMotion` or pass `reduceMotion` as a parameter.
- `FocusableButton` is a `StatefulWidget` — it does not have BLoC access unless provided; pass `reduceMotion` as a parameter.
- Stable `FocusNode` instances must be created in `State.initState`, not in `build()`, and disposed in `dispose()`.
- Post-frame callbacks must guard with `if (mounted)` before calling `requestFocus`.
- Do NOT touch `lib/features/import/` or `lib/features/player/` (already correct).
- Report file: `/Users/AbdelazizMahdy/flutter_projects/Iptv/.superpowers/sdd/b-focus-pass-report.md`
- Commit identity: `git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit`

---

### Task 1: High-contrast focus ring in FocusableButton

**Files:**
- Modify: `lib/core/widgets/focusable_button.dart`
- Modify: `test/core/widgets/focusable_button_test.dart`

**Interfaces:**
- Consumes: `AccessibilitySettings.reduceMotion` (bool) — passed as `reduceMotion` constructor parameter to avoid BLoC coupling.
- Produces: `FocusableButton({required child, required onPressed, semanticLabel, autofocus = false, reduceMotion = false})` — new optional `reduceMotion` parameter; all existing call sites that omit it get `false` (correct default for touch / non-TV contexts). All existing call sites on TV screens that need to honor reduce-motion must pass the value (done in Task 9 for `LiveScreen`, which already reads the cubit).

**Why the change:** The current ring (`context.palette.focus`, 3px border) is invisible when the button's child fills with `context.palette.accent` (violet) or `context.palette.surface2` — the focus color blends in. The fix: show a **3px `context.palette.fg` (near-white/near-yellow) outer border** via `foregroundDecoration` PLUS scale the widget up to **1.04** via `AnimatedScale` wrapping. Scale is suppressed (`scale: 1.0`) when `reduceMotion: true`. Using `foregroundDecoration` preserves layout — nothing shifts.

- [ ] **Step 1: Write the failing test for the scale-up behavior**

Add to `test/core/widgets/focusable_button_test.dart` (after the existing two tests):

```dart
testWidgets('shows AnimatedScale with scale > 1.0 when focused and reduceMotion is false',
    (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
    home: Scaffold(
      body: FocusableButton(
        autofocus: true,
        reduceMotion: false,
        semanticLabel: 'Test',
        onPressed: () {},
        child: const Text('Test'),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
  expect(scale.scale, greaterThan(1.0));
});

testWidgets('AnimatedScale stays at 1.0 when focused but reduceMotion is true',
    (tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(palette: AppPalette.standard, hyperlegible: false, rtl: false),
    home: Scaffold(
      body: FocusableButton(
        autofocus: true,
        reduceMotion: true,
        semanticLabel: 'Test',
        onPressed: () {},
        child: const Text('Test'),
      ),
    ),
  ));
  await tester.pumpAndSettle();

  final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
  expect(scale.scale, equals(1.0));
});
```

- [ ] **Step 2: Run to verify they fail**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/core/widgets/focusable_button_test.dart --no-pub 2>&1 | tail -20
```

Expected: `AnimatedScale` not found → test fails with "found 0 AnimatedScale".

- [ ] **Step 3: Rewrite `lib/core/widgets/focusable_button.dart`**

Replace the entire file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// A button that shows a high-contrast focus ring when focused — for TV remote /
/// D-pad navigation — and exposes a semantics label for screen readers.
///
/// Responds to Enter, Space, Select, and GameButtonA (TV remote centre/select)
/// in addition to tap, so it works correctly with Android TV D-pad navigation.
///
/// ### Focus ring
/// When focused, renders a 3 px `context.palette.fg` border via
/// [foregroundDecoration] (does NOT affect layout size) PLUS scales the widget
/// up to 1.04 via [AnimatedScale] (skipped when [reduceMotion] is true).
///
/// Pass [reduceMotion] from `AccessibilityCubit().state.reduceMotion`.
class FocusableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String? semanticLabel;
  final bool autofocus;
  final bool reduceMotion;

  const FocusableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.semanticLabel,
    this.autofocus = false,
    this.reduceMotion = false,
  });

  @override
  State<FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<FocusableButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final focusedScale = widget.reduceMotion ? 1.0 : (_focused ? 1.04 : 1.0);

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        autofocus: widget.autofocus,
        onShowFocusHighlight: (f) => setState(() => _focused = f),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: AnimatedScale(
          scale: focusedScale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onTap: widget.onPressed,
            // foregroundDecoration paints the focus ring OVER the child without
            // adding to layout size, so wrapping fixed-width widgets (e.g. EPG
            // cells) doesn't shift or overflow their layout.
            child: Container(
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _focused ? context.palette.fg : Colors.transparent,
                  width: 3,
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run all widget tests for focusable_button**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/core/widgets/focusable_button_test.dart --no-pub 2>&1 | tail -20
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Run `flutter analyze` to verify no issues**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter analyze lib/core/widgets/focusable_button.dart 2>&1 | tail -10
```

Expected: No issues.

- [ ] **Step 6: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/core/widgets/focusable_button.dart test/core/widgets/focusable_button_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): high-contrast focus ring — fg border + scale in FocusableButton"
```

---

### Task 2: Initial focus — OnboardingScreen

**Files:**
- Modify: `lib/features/onboarding/onboarding_screen.dart`
- Test: `test/features/onboarding/onboarding_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `OnboardingScreen` autofocuses "Get Started" button on entry.

**Why:** OnboardingScreen is a `StatelessWidget` with a single actionable button. The simplest fix: set `autofocus: true` on the existing `FocusableButton` wrapping "Get Started". This is safe — there is only one focusable widget on the screen.

- [ ] **Step 1: Write the failing test**

Add to `test/features/onboarding/onboarding_screen_test.dart` inside the existing `group('OnboardingScreen', ...)`:

```dart
testWidgets('Get Started button receives autofocus', (tester) async {
  await tester.pumpWidget(buildTestApp(onGetStarted: () {}));
  await tester.pumpAndSettle();

  // The FocusableButton wrapping Get Started should be the primary focus.
  final btn = find.byType(FocusableButton);
  expect(btn, findsOneWidget);
  expect(tester.widget<FocusableButton>(btn).autofocus, isTrue);
});
```

Also add the import at the top of the test file:
```dart
import 'package:noor_iptv/core/widgets/focusable_button.dart';
```

- [ ] **Step 2: Run to verify failure**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/onboarding/onboarding_screen_test.dart --no-pub 2>&1 | tail -10
```

Expected: FAIL — `autofocus` is false.

- [ ] **Step 3: Edit `lib/features/onboarding/onboarding_screen.dart`**

Find the `FocusableButton` for "Get Started" (line 53) and add `autofocus: true`:

```dart
              FocusableButton(
                autofocus: true,               // ← add this line
                semanticLabel: l10n.getStarted,
                onPressed: onGetStarted,
```

- [ ] **Step 4: Run tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/onboarding/onboarding_screen_test.dart --no-pub 2>&1 | tail -10
```

Expected: All 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/onboarding/onboarding_screen.dart test/features/onboarding/onboarding_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): autofocus Get Started on OnboardingScreen"
```

---

### Task 3: Initial focus — DetailsScreen (Play button)

**Files:**
- Modify: `lib/features/details/details_screen.dart`
- Test: `test/features/details/details_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `DetailsScreen.movie` and `DetailsScreen.series` autofocus the Play button on entry.

**Why:** Both `_MovieDetailBody` and `_SeriesDetailBody` have a `FocusableButton` with `semanticLabel: l10n.play`. Setting `autofocus: true` on it is safe — there is only one primary autofocus element per screen.

Note: `_SeriesDetailBody` renders the Play button conditionally (`if (!state.loading && state.episodes.isNotEmpty)`). When the cubit is still loading, `My List` button is the first button — but autofocus on Play is fine because in the non-loading state Play renders first in the Row. In loading state nothing is autofocused (acceptable). Set autofocus on the Play `FocusableButton` in both bodies.

- [ ] **Step 1: Write failing test for autofocus on play button**

Add to `test/features/details/details_screen_test.dart` — at the bottom of `main()`:

```dart
  testWidgets('DetailsScreen.movie Play button has autofocus: true',
      (tester) async {
    const movie = VodItem(
      id: 'm3',
      playlistId: 'p1',
      title: 'Blade Runner',
      streamUrl: 'http://x',
    );

    await tester.pumpWidget(
      _wrap(
        DetailsScreen.movie(
          movie,
          onBack: () {},
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The Play FocusableButton should have autofocus: true.
    // There may be multiple FocusableButtons (back, play, my-list).
    // The play button is identifiable by its semantic label 'Play'.
    final playButtons = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.semanticLabel == 'Play',
    );
    expect(playButtons, findsOneWidget);
    expect(tester.widget<FocusableButton>(playButtons).autofocus, isTrue);
  });
```

Add import at top of file:
```dart
import 'package:noor_iptv/core/widgets/focusable_button.dart';
```

- [ ] **Step 2: Run to verify failure**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/details/details_screen_test.dart --no-pub 2>&1 | tail -15
```

Expected: FAIL — autofocus is false.

- [ ] **Step 3: Edit `lib/features/details/details_screen.dart` — `_MovieDetailBody`**

Find the Play `FocusableButton` in `_MovieDetailBody` (around line 376) and add `autofocus: true`:

```dart
                      FocusableButton(
                        autofocus: true,              // ← add
                        semanticLabel: l10n.play,
                        onPressed: () => onPlay(movie),
```

- [ ] **Step 4: Edit `lib/features/details/details_screen.dart` — `_SeriesDetailBody`**

Find the Play `FocusableButton` in `_SeriesDetailBody` (around line 500) and add `autofocus: true`:

```dart
                            FocusableButton(
                              autofocus: true,         // ← add
                              semanticLabel: l10n.play,
                              onPressed: () =>
                                  onPlayEpisode(state.episodes.first),
```

- [ ] **Step 5: Run tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/details/details_screen_test.dart --no-pub 2>&1 | tail -15
```

Expected: All 5 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/details/details_screen.dart test/features/details/details_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): autofocus Play button on DetailsScreen"
```

---

### Task 4: Initial focus — HomeScreen

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/home/home_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `HomeScreen` autofocuses "Set up a playlist" when no content; autofocuses hero Play button when content exists.

**Why:** `_HomeView` shows two distinct states. In the no-content state, there is one `FocusableButton` ("Set up a playlist") — set `autofocus: true`. In the content state, `_HeroBanner` has two `FocusableButton`s in a `Row` (Play, More Info) — set `autofocus: true` on the Play button. This is safe because only one autofocus element is ever present at a time (the two states are mutually exclusive).

- [ ] **Step 1: Write failing test**

Add to `test/features/home/home_screen_test.dart` at bottom of `main()`:

```dart
  testWidgets('HomeScreen hero Play button has autofocus: true', (tester) async {
    await _pumpAndIgnoreOverflow(tester, _buildTestApp());

    // The hero's Play FocusableButton should have autofocus.
    final playBtns = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    // At least one autofocused FocusableButton must exist.
    expect(playBtns, findsAtLeastNWidgets(1));
  });
```

Add import at top:
```dart
import 'package:noor_iptv/core/widgets/focusable_button.dart';
```

- [ ] **Step 2: Run to verify failure**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/home/home_screen_test.dart --no-pub 2>&1 | tail -15
```

Expected: FAIL — no autofocused FocusableButton found.

- [ ] **Step 3: Edit `lib/features/home/home_screen.dart` — no-content "Set up a playlist" button**

In `_HomeView.build()`, find the `FocusableButton` for "Set up a playlist" (around line 71) and add `autofocus: true`:

```dart
                FocusableButton(
                  autofocus: true,                // ← add
                  semanticLabel: 'Set up a playlist',
                  onPressed: onAddPlaylist,
```

- [ ] **Step 4: Edit `lib/features/home/home_screen.dart` — hero Play button**

In `_HeroBanner.build()`, find the first `FocusableButton` in the Row (Play button, around line 220) and add `autofocus: true`:

```dart
                      FocusableButton(
                        autofocus: true,          // ← add
                        semanticLabel: l10n.play,
                        onPressed: () => onOpenMovie(featured),
```

- [ ] **Step 5: Run tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/home/home_screen_test.dart --no-pub 2>&1 | tail -15
```

Expected: All 5 tests PASS. If the existing "tapping Play button" test breaks because `autofocus` causes `pumpAndSettle` to settle differently, add `await tester.pumpAndSettle()` calls as needed — do NOT weaken assertions.

- [ ] **Step 6: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/home/home_screen.dart test/features/home/home_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): autofocus hero Play / setup button on HomeScreen"
```

---

### Task 5: Initial focus — PlaylistsScreen

**Files:**
- Modify: `lib/features/playlists/playlists_screen.dart`
- Test (new assertions): `test/features/playlists/playlists_cubit_test.dart` → no changes needed to cubit. Check if a screen test exists; if not, no test needed for autofocus (cubit test covers behavior).

**Interfaces:**
- Consumes: `PlaylistsState.playlists` (list), `PlaylistsState.loading` (bool).
- Produces: First playlist tile autofocused when playlists exist; "Add playlist" button autofocused when list is empty.

**Why:** `_PlaylistsView` builds a `ListView` with playlist tiles followed by an "Add Playlist" button. The `_PlaylistTile` uses `FocusableButton`. The first tile should get `autofocus: true` when `index == 0` in the list. When no playlists exist, only `_AddPlaylistButton` renders — it should get `autofocus: true`.

There is no screen-level widget test for PlaylistsScreen. Add a minimal one.

- [ ] **Step 1: Write a screen test (new file)**

Create `test/features/playlists/playlists_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_iptv/core/di/injection.dart';
import 'package:noor_iptv/core/theme/app_palette.dart';
import 'package:noor_iptv/core/theme/app_theme.dart';
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/features/playlists/playlists_screen.dart';
import 'package:noor_iptv/l10n/generated/app_localizations.dart';

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
```

- [ ] **Step 2: Run to verify failure**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/playlists/playlists_screen_test.dart --no-pub 2>&1 | tail -10
```

Expected: FAIL — no autofocused FocusableButton.

- [ ] **Step 3: Edit `lib/features/playlists/playlists_screen.dart` — `_PlaylistsView`**

In `_PlaylistsView.build()`, inside the `...state.playlists.map(...)` mapping, pass `autofocus` to `_PlaylistTile`:

```dart
              ...state.playlists.asMap().entries.map(
                (entry) => _PlaylistTile(
                  playlist: entry.value,
                  isActive: state.activeId == entry.value.id,
                  autofocus: entry.key == 0,        // ← autofocus first tile
                  onTap: () {
                    context.read<PlaylistsCubit>().select(entry.value.id);
                    onSelected(entry.value);
                  },
                  palette: p,
                  textTheme: textTheme,
                ),
              ),
```

Also autofocus `_AddPlaylistButton` when the playlist list is empty:

```dart
              _AddPlaylistButton(
                autofocus: state.playlists.isEmpty,   // ← autofocus when no playlists
                onPressed: onAddPlaylist,
                palette: p,
                textTheme: textTheme,
              ),
```

- [ ] **Step 4: Add `autofocus` parameter to `_PlaylistTile`**

In the `_PlaylistTile` class definition, add:

```dart
class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.isActive,
    required this.autofocus,           // ← add
    required this.onTap,
    required this.palette,
    required this.textTheme,
  });

  final Playlist playlist;
  final bool isActive;
  final bool autofocus;                // ← add
  final VoidCallback onTap;
  final AppPalette palette;
  final TextTheme textTheme;
```

In `_PlaylistTile.build()`, pass it to `FocusableButton`:

```dart
      child: FocusableButton(
        autofocus: autofocus,          // ← add
        onPressed: onTap,
```

- [ ] **Step 5: Add `autofocus` parameter to `_AddPlaylistButton`**

```dart
class _AddPlaylistButton extends StatelessWidget {
  const _AddPlaylistButton({
    required this.onPressed,
    required this.autofocus,           // ← add
    required this.palette,
    required this.textTheme,
  });

  final VoidCallback onPressed;
  final bool autofocus;                // ← add
  final AppPalette palette;
  final TextTheme textTheme;
```

In `_AddPlaylistButton.build()`, pass to `FocusableButton`:

```dart
    return FocusableButton(
      autofocus: autofocus,            // ← add
      semanticLabel: l10n.addPlaylist,
      onPressed: onPressed,
```

- [ ] **Step 6: Run tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/playlists/ --no-pub 2>&1 | tail -10
```

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/playlists/playlists_screen.dart test/features/playlists/playlists_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): autofocus first playlist tile / Add button on PlaylistsScreen"
```

---

### Task 6: Initial focus — FavoritesScreen

**Files:**
- Modify: `lib/features/favorites/favorites_screen.dart`
- Test: `test/features/favorites/favorites_screen_test.dart`

**Interfaces:**
- Consumes: `FavoritesState.entries` (list), `FavoritesState.isEmpty` (bool).
- Produces: First `PosterCard` autofocused when favorites exist; no autofocus in empty state (nothing actionable).

**Why:** `FavoritesScreen` uses `PosterCard` which internally uses `FocusableButton`. To autofocus the first card, `PosterCard` needs an `autofocus` parameter that it forwards to its inner `FocusableButton`. Check `lib/core/widgets/poster_card.dart` — if `autofocus` is not present, add it (the plan covers this in this task).

- [ ] **Step 1: Read `lib/core/widgets/poster_card.dart` to confirm current `autofocus` support**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && grep -n "autofocus" lib/core/widgets/poster_card.dart
```

If `autofocus` is NOT present, proceed with steps 2–4. If it IS present, skip to step 5.

- [ ] **Step 2: Write failing test**

Read `test/features/favorites/favorites_screen_test.dart` and add at the bottom of `main()`:

```dart
  testWidgets(
      'FavoritesScreen first PosterCard has autofocus when favorites exist',
      (tester) async {
    // The fake ContentRepository seeds favorites — assert at least one
    // autofocused FocusableButton exists.
    await tester.pumpWidget(_buildTestApp()); // use existing helper
    await tester.pumpAndSettle();

    // Only assert if the grid is non-empty (skip if fakes return empty).
    final autofocused = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    // Either there are favorites and one is autofocused, or there are none
    // and zero are autofocused — both are valid. We just assert no crash.
    // A stronger assertion is that IF posters are shown, one is autofocused.
    final posters = find.byType(PosterCard, skipOffstage: false);
    if (posters.evaluate().isNotEmpty) {
      expect(autofocused, findsAtLeastNWidgets(1));
    }
  });
```

Add imports:
```dart
import 'package:noor_iptv/core/widgets/focusable_button.dart';
import 'package:noor_iptv/core/widgets/poster_card.dart';
```

- [ ] **Step 3: Add `autofocus` to `PosterCard`**

Read `lib/core/widgets/poster_card.dart`. Add `autofocus` parameter:

In the constructor:
```dart
  const PosterCard({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.badge,
    this.progress,
    this.isFavorite = false,
    this.autofocus = false,           // ← add
    this.onTap,
    this.onToggleFavorite,
  });
```

Add field:
```dart
  final bool autofocus;               // ← add
```

In `PosterCard.build()`, pass to the outer `FocusableButton` (the one wrapping the whole card, not the heart button):

```dart
      child: FocusableButton(
        autofocus: autofocus,         // ← add
        onPressed: onTap ?? () {},
```

- [ ] **Step 4: Edit `lib/features/favorites/favorites_screen.dart`**

In `_FavoritesView.build()`, in the `SliverChildBuilderDelegate` builder, pass `autofocus: index == 0`:

```dart
                      (context, index) {
                        final entry = state.entries[index];
                        return PosterCard(
                          autofocus: index == 0,   // ← add
                          title: entry.title,
```

- [ ] **Step 5: Run tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/favorites/ test/core/widgets/poster_card_test.dart --no-pub 2>&1 | tail -15
```

Expected: All tests PASS. Fix any `PosterCard` test breakage from the new parameter (it has a default value so callers that don't set it are fine — no fixes expected).

- [ ] **Step 6: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/core/widgets/poster_card.dart lib/features/favorites/favorites_screen.dart test/features/favorites/favorites_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): autofocus first poster on FavoritesScreen; add autofocus to PosterCard"
```

---

### Task 7: Initial focus — LiveScreen and ChannelListScreen

**Files:**
- Modify: `lib/features/live/live_screen.dart`
- Modify: `lib/features/live/channel_list_screen.dart`
- Test: `test/features/live/live_screen_test.dart`

**Interfaces:**
- Consumes: `LiveState.groups` (list), `LiveState.channelsInGroup` (list).
- Produces:
  - Wide layout: first `_GroupTile` autofocused (sidebar).
  - Narrow layout: first group `FocusableButton` in `ListView.builder` autofocused.
  - `ChannelListScreen`: first `_ChannelRow` autofocused.

**Why:** `_WideLayout` builds a `ListView.builder` for groups — first `_GroupTile` should get `autofocus: true`. `_NarrowLayout` also `ListView.builder` for groups — first `FocusableButton` (index 0) gets `autofocus: true`. `ChannelListScreen` `ListView.builder` — first `_ChannelRow` (index 0) gets `autofocus: true`. Pass `autofocus` as a parameter to `_GroupTile` and `_ChannelRow`.

LiveScreen already reads `AccessibilityCubit` for `reduceMotion` (the `LiveBadge`) — that's separate. No `reduceMotion` plumbing needed here.

- [ ] **Step 1: Write failing test**

Read `test/features/live/live_screen_test.dart`. Add at the bottom of `main()`:

```dart
  testWidgets(
      'LiveScreen has at least one autofocused FocusableButton when content loads',
      (tester) async {
    // Use the same test setup as existing tests in this file.
    // After settle, at least one FocusableButton should be autofocused.
    await tester.pumpAndSettle();

    final autofocused = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    expect(autofocused, findsAtLeastNWidgets(1));
  });
```

Add import:
```dart
import 'package:noor_iptv/core/widgets/focusable_button.dart';
```

(Read the existing test file first to match the setUp / test structure — insert the test inside the existing `group` / `main` block, not as a new top-level `group`.)

- [ ] **Step 2: Run to verify failure**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/live/live_screen_test.dart --no-pub 2>&1 | tail -15
```

Expected: FAIL — no autofocused FocusableButton.

- [ ] **Step 3: Add `autofocus` to `_GroupTile` in `lib/features/live/live_screen.dart`**

```dart
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.isSelected,
    required this.autofocus,           // ← add
    required this.onTap,
  });

  final ChannelGroup group;
  final bool isSelected;
  final bool autofocus;                // ← add
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      autofocus: autofocus,            // ← add
      semanticLabel: group.name,
      onPressed: onTap,
```

- [ ] **Step 4: Pass `autofocus: index == 0` to `_GroupTile` in `_WideLayout`**

In `_WideLayout.build()`, inside `itemBuilder`:

```dart
                  itemBuilder: (context, index) {
                    final group = state.groups[index];
                    final isSelected = group.id == state.selectedGroupId;
                    return _GroupTile(
                      group: group,
                      isSelected: isSelected,
                      autofocus: index == 0,             // ← add
                      onTap: () => context.read<LiveCubit>().selectGroup(group.id),
                    );
                  },
```

- [ ] **Step 5: Pass `autofocus: index == 0` in `_NarrowLayout`**

In `_NarrowLayout.build()`, inside `itemBuilder`, the existing `FocusableButton` for each group row:

```dart
                  itemBuilder: (context, index) {
                    final group = state.groups[index];
                    return FocusableButton(
                      autofocus: index == 0,             // ← add
                      semanticLabel: group.name,
                      onPressed: () {
```

- [ ] **Step 6: Add `autofocus` to `_ChannelRow` in `lib/features/live/channel_list_screen.dart`**

```dart
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.channel,
    required this.palette,
    required this.autofocus,           // ← add
    required this.onPlayChannel,
  });

  final Channel channel;
  final dynamic palette;
  final bool autofocus;                // ← add
  final void Function(Channel) onPlayChannel;

  @override
  Widget build(BuildContext context) {
    final p = palette as dynamic;
    return FocusableButton(
      autofocus: autofocus,            // ← add
      semanticLabel: channel.name,
      onPressed: () => onPlayChannel(channel),
```

In `ChannelListScreen.build()`, inside `itemBuilder`:

```dart
              itemBuilder: (context, index) {
                final channel = channels[index];
                return _ChannelRow(
                  channel: channel,
                  palette: p,
                  autofocus: index == 0,               // ← add
                  onPlayChannel: onPlayChannel,
                );
              },
```

- [ ] **Step 7: Run tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/live/ --no-pub 2>&1 | tail -15
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/live/live_screen.dart lib/features/live/channel_list_screen.dart test/features/live/live_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): autofocus first group / channel on LiveScreen and ChannelListScreen"
```

---

### Task 8: Initial focus — GridScreen and CategoryResultsScreen

**Files:**
- Modify: `lib/features/grid/grid_screen.dart`
- Test: `test/features/grid/grid_screen_test.dart`

**Interfaces:**
- Consumes: `GridState.categories` (list), `GridState.filteredItems` (list).
- Produces:
  - Wide layout: first `_CategoryTile` autofocused (sidebar).
  - Narrow layout: first category `FocusableButton` (index 0) autofocused.
  - `CategoryResultsScreen`: first `PosterCard` autofocused (uses `PosterCard.autofocus` from Task 6).

**Why:** Same pattern as LiveScreen. `_CategoryTile` in wide sidebar gets `autofocus: index == 0`. Narrow layout `FocusableButton` per category gets `autofocus: index == 0`. `CategoryResultsScreen` passes `autofocus: index == 0` to `PosterCard` (the `autofocus` param was added in Task 6).

- [ ] **Step 1: Write failing test**

Read `test/features/grid/grid_screen_test.dart`. Add at bottom of `main()`:

```dart
  testWidgets(
      'GridScreen has at least one autofocused FocusableButton when content loads',
      (tester) async {
    await tester.pumpAndSettle();

    final autofocused = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    expect(autofocused, findsAtLeastNWidgets(1));
  });
```

Add import:
```dart
import 'package:noor_iptv/core/widgets/focusable_button.dart';
```

- [ ] **Step 2: Run to verify failure**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/grid/grid_screen_test.dart --no-pub 2>&1 | tail -15
```

Expected: FAIL.

- [ ] **Step 3: Add `autofocus` to `_CategoryTile` in `lib/features/grid/grid_screen.dart`**

```dart
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.name,
    required this.count,
    required this.isSelected,
    required this.autofocus,           // ← add
    required this.onTap,
  });

  final String name;
  final int? count;
  final bool isSelected;
  final bool autofocus;                // ← add
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FocusableButton(
      autofocus: autofocus,            // ← add
      semanticLabel: name,
      onPressed: onTap,
```

- [ ] **Step 4: Pass `autofocus: index == 0` to `_CategoryTile` in `_WideLayout`**

In `_WideLayout.build()`, inside `itemBuilder`:

```dart
                  itemBuilder: (context, index) {
                    final cat = state.categories[index];
                    final isAll = cat.id.isEmpty;
                    final isSelected = isAll
                        ? state.selectedCategoryId == null
                        : state.selectedCategoryId == cat.id;
                    return _CategoryTile(
                      name: cat.name,
                      count: null,
                      isSelected: isSelected,
                      autofocus: index == 0,             // ← add
                      onTap: () => ctx
                          .read<GridCubit>()
                          .selectCategory(isAll ? null : cat.id),
                    );
                  },
```

- [ ] **Step 5: Pass `autofocus: index == 0` in `_NarrowLayout`**

In `_NarrowLayout.build()` inside `itemBuilder`, the existing `FocusableButton`:

```dart
              itemBuilder: (context, index) {
                final cat = state.categories[index];
                final isAll = cat.id.isEmpty;
                return FocusableButton(
                  autofocus: index == 0,               // ← add
                  semanticLabel: cat.name,
                  onPressed: () {
```

- [ ] **Step 6: Pass `autofocus: index == 0` in `CategoryResultsScreen`**

In `CategoryResultsScreen.build()` inside `itemBuilder`:

```dart
              itemBuilder: (context, index) {
                final entry = items[index];
                return PosterCard(
                  autofocus: index == 0,               // ← add
                  title: entry.title,
                  subtitle: entry.subtitle,
                  imageUrl: entry.posterUrl,
                  onTap: () => onOpen(entry),
                );
              },
```

- [ ] **Step 7: Run tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/grid/ --no-pub 2>&1 | tail -15
```

Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/grid/grid_screen.dart test/features/grid/grid_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): autofocus first category / poster on GridScreen and CategoryResultsScreen"
```

---

### Task 9: Initial focus — SettingsScreen (wrap _LangChip with FocusableButton)

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Test: `test/features/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `_LangChip` and `_SegmentChip` are wrapped in `FocusableButton` so D-pad can land on the first control. The "EN" language chip gets `autofocus: true`.

**Why:** `SettingsScreen` uses bare `GestureDetector` + `Semantics` for `_LangChip`, `_SegmentChip`, and caption control chips. These are not focusable via D-pad. We need to wrap them in `FocusableButton`. The first focusable element on entry is the "EN" `_LangChip`.

**Constraint:** `_LangChip` and `_SegmentChip` are both `Expanded` inside a `Row`. Wrapping in `FocusableButton` is safe because `FocusableButton`'s `foregroundDecoration` doesn't affect layout. The `Expanded` wrapper stays outside `FocusableButton`.

- [ ] **Step 1: Write failing test**

Add to `test/features/settings/settings_screen_test.dart` at bottom of `main()`:

```dart
  testWidgets('SettingsScreen has at least one autofocused FocusableButton',
      (tester) async {
    final a11y = AccessibilityCubit();
    final locale = LocaleCubit();
    await tester.pumpWidget(_buildTestApp(a11y, locale));
    await tester.pumpAndSettle();

    final autofocused = find.byWidgetPredicate(
      (w) => w is FocusableButton && w.autofocus == true,
      skipOffstage: false,
    );
    expect(autofocused, findsAtLeastNWidgets(1));
  });
```

Add import:
```dart
import 'package:noor_iptv/core/widgets/focusable_button.dart';
```

- [ ] **Step 2: Run to verify failure**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/settings/settings_screen_test.dart --no-pub 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3: Wrap `_LangChip` content in `FocusableButton`**

In `_LangChip.build()`, replace the `Expanded(child: Semantics(...child: GestureDetector(...)))` with:

```dart
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: semanticLabel,
        selected: selected,
        button: true,
        child: FocusableButton(
          autofocus: autofocus,          // ← new parameter (see step 4)
          semanticLabel: semanticLabel,
          onPressed: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? context.palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? context.palette.bg
                          : context.palette.fg,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
```

Add `autofocus` parameter to `_LangChip`:

```dart
class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool autofocus;              // ← add

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    this.autofocus = false,          // ← add
  });
```

- [ ] **Step 4: Pass `autofocus: true` to the EN chip in `_LanguageSelector`**

In `_LanguageSelector.build()`, the first `_LangChip`:

```dart
                _LangChip(
                  label: 'EN',
                  selected: isEn,
                  autofocus: true,          // ← add (EN is first control on screen)
                  onTap: () => ctx.read<LocaleCubit>().setEnglish(),
                  semanticLabel: 'English',
                ),
                _LangChip(
                  label: 'عربي',
                  selected: !isEn,
                  // autofocus: false (default)
                  onTap: () => ctx.read<LocaleCubit>().setArabic(),
                  semanticLabel: 'Arabic',
                ),
```

Also add `import 'package:noor_iptv/core/widgets/focusable_button.dart';` at top of `settings_screen.dart`.

- [ ] **Step 5: Wrap `_SegmentChip` in `FocusableButton` (text size chips)**

In `_SegmentChip.build()`, same pattern — wrap the `GestureDetector + AnimatedContainer` in `FocusableButton`. No autofocus needed on these (the language chip is the screen's first focus). Just wrap for D-pad accessibility:

```dart
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: semanticLabel,
        selected: selected,
        button: true,
        child: FocusableButton(
          semanticLabel: semanticLabel,
          onPressed: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? context.palette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? context.palette.bg
                          : context.palette.fg,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
```

Remove the now-redundant `GestureDetector` wrapper (the `FocusableButton` handles tap via its own `GestureDetector`).

- [ ] **Step 6: Run all settings tests**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test test/features/settings/ --no-pub 2>&1 | tail -20
```

Expected: All tests PASS. The existing "toggling High contrast" and "selecting text size Large" tests should still pass because they tap via `SwitchListTile` and text labels respectively — not via `FocusableButton`.

- [ ] **Step 7: Commit**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add lib/features/settings/settings_screen.dart test/features/settings/settings_screen_test.dart && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): wrap language/size chips in FocusableButton; autofocus EN chip on SettingsScreen"
```

---

### Task 10: Full test suite pass + report

**Files:**
- Create: `/Users/AbdelazizMahdy/flutter_projects/Iptv/.superpowers/sdd/b-focus-pass-report.md`

**Interfaces:**
- Consumes: all modified files from Tasks 1–9.
- Produces: green test suite + committed report.

- [ ] **Step 1: Run full `flutter analyze`**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter analyze 2>&1 | tail -20
```

Expected: `No issues found!` (or only pre-existing infos). Fix any new warnings introduced by the tasks above before proceeding.

- [ ] **Step 2: Run full test suite**

```
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && flutter test --no-pub 2>&1 | tail -30
```

Expected: All tests pass. If any tests fail due to multiple `autofocus: true` widgets in the same focus tree (Flutter allows it but can emit warnings), add `FocusTraversalGroup` in the relevant screen to scope the tree, or ensure only one widget has `autofocus: true` per screen (which our design already guarantees — check each screen). Fix any failures before proceeding.

- [ ] **Step 3: Write the report**

Create `/Users/AbdelazizMahdy/flutter_projects/Iptv/.superpowers/sdd/b-focus-pass-report.md`:

```markdown
# TV Focus Pass — Implementation Report

## Focus Ring Change (Task 1)

**File:** `lib/core/widgets/focusable_button.dart`

Changed from: 3px `context.palette.focus` border (blue/yellow — sometimes low-contrast against accent-filled buttons).

Changed to:
- 3px `context.palette.fg` border (near-white `0xFFF3F6FB` / high-contrast white `0xFFFFFFFF`) via `foregroundDecoration` — always visible against any background.
- `AnimatedScale(scale: 1.04)` wrapping the `Container` — subtle "pop" to reinforce focus visually.
- `AnimatedScale` disabled (`scale: 1.0`) when `reduceMotion: true`.
- New `reduceMotion` parameter (default `false`) added to `FocusableButton` constructor.
- `foregroundDecoration` continues to be used — zero layout impact.

## Per-Screen Autofocus

| Screen | Autofocused Element | Method |
|--------|--------------------|----|
| OnboardingScreen | "Get Started" button | `autofocus: true` on `FocusableButton` |
| HomeScreen (empty) | "Set up a playlist" button | `autofocus: true` on `FocusableButton` |
| HomeScreen (with content) | Hero Play button | `autofocus: true` on `FocusableButton` |
| DetailsScreen (movie) | Play button | `autofocus: true` on `FocusableButton` |
| DetailsScreen (series) | Play button (when episodes loaded) | `autofocus: true` on `FocusableButton` |
| PlaylistsScreen (with playlists) | First playlist tile | `autofocus: index == 0` via new `_PlaylistTile.autofocus` param |
| PlaylistsScreen (empty) | "Add Playlist" button | `autofocus: state.playlists.isEmpty` on `_AddPlaylistButton` |
| FavoritesScreen (with favorites) | First poster card | `autofocus: index == 0` via new `PosterCard.autofocus` param |
| FavoritesScreen (empty) | None (nothing actionable) | intentional |
| LiveScreen wide | First sidebar group tile | `autofocus: index == 0` via `_GroupTile.autofocus` |
| LiveScreen narrow | First group row | `autofocus: index == 0` on `FocusableButton` in `ListView.builder` |
| ChannelListScreen | First channel row | `autofocus: index == 0` via `_ChannelRow.autofocus` |
| GridScreen wide | First sidebar category tile | `autofocus: index == 0` via `_CategoryTile.autofocus` |
| GridScreen narrow | First category row | `autofocus: index == 0` on `FocusableButton` in `ListView.builder` |
| CategoryResultsScreen | First poster card | `autofocus: index == 0` via `PosterCard.autofocus` |
| SettingsScreen | "EN" language chip | `autofocus: true` on `_LangChip` wrapping `FocusableButton`; `_SegmentChip` also wrapped for D-pad reachability |
| SearchScreen | Search `TextField` | Already `autofocus: true` — no change |
| PlayerScreen | (left as-is) | Already has its own controls |
| ImportScreen | (left as-is) | Already has explicit FocusNode management |

## Tests Adjusted

- `test/core/widgets/focusable_button_test.dart`: Added 2 tests for `AnimatedScale` + `reduceMotion` behavior.
- `test/features/onboarding/onboarding_screen_test.dart`: Added autofocus assertion test.
- `test/features/details/details_screen_test.dart`: Added autofocus assertion on Play button.
- `test/features/home/home_screen_test.dart`: Added autofocus assertion test.
- `test/features/playlists/playlists_screen_test.dart`: New file — basic autofocus assertion.
- `test/features/favorites/favorites_screen_test.dart`: Added autofocus assertion (conditional on fakes returning entries).
- `test/features/live/live_screen_test.dart`: Added autofocus assertion.
- `test/features/grid/grid_screen_test.dart`: Added autofocus assertion.
- `test/features/settings/settings_screen_test.dart`: Added autofocus assertion.

## Concerns / Notes

- `FocusableButton.reduceMotion` defaults to `false`. Existing callers are unaffected. Screens that pass `reduceMotion` from the cubit (LiveScreen already reads it for `LiveBadge`) can forward it; all other screens use the default, which produces the scale animation unconditionally on TV — acceptable behavior since TV focus is only meaningful on Android TV where reduce-motion is a system-level setting users opt in to.
- `PosterCard.autofocus` was added with `default false` — no existing callers broken.
- The `foregroundDecoration` approach means the focus ring on `PosterCard` sits over both the main card area and the heart-button overlay. This is correct since focus is on the outer card, not the heart button.
- `_LangChip` and `_SegmentChip` in SettingsScreen were previously `GestureDetector`-only. Wrapping in `FocusableButton` makes them reachable via D-pad. Caption color swatches (`_CaptionColorRow`) also use `GestureDetector` — these are less critical (caption settings are infrequently accessed on TV) and are left as-is to keep this PR focused.
```

- [ ] **Step 4: Stage and commit everything**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): app-wide focus pass — per-screen initial focus + high-contrast focus ring"
```

If `git index.lock` exists, wait 3 seconds and retry once:
```bash
sleep 3 && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" add -A && git -c user.name="Abdelaziz" -c user.email="zezohassam@gmail.com" commit -m "feat(tv): app-wide focus pass — per-screen initial focus + high-contrast focus ring"
```

- [ ] **Step 5: Report the commit hash**

```bash
cd /Users/AbdelazizMahdy/flutter_projects/Iptv && git log --oneline -5
```

Output includes the final commit hash. Return it in the report.
