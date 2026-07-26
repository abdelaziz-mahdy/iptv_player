# lib/core — Shared Infrastructure

## di/ — Dependency Injection

`injection.dart` exposes the global `GetIt sl = GetIt.instance`.

GOTCHA: registration is **manual** — no `injectable` annotations, no code-gen. Every dependency is
registered explicitly with `registerLazySingleton` / `registerSingleton`.

Two entry points:
- `configureDependencies()` — in-memory fakes; used by widget tests.
- `configureProductionDependencies()` — drift-backed real stores; called by `main.dart`.

Never call both in the same process; `GetIt` will throw on double registration.

## router/ — Navigation

`app_router.dart` builds a `GoRouter` using `StatefulShellRoute.indexedStack` for the six main tabs
(Home, Favorites, Live, Movies, Series, Search). The shell widget is `widgets/adaptive_shell.dart`.

Pushed routes (outside the shell): `/player`, `/details/movie`, `/details/series`, `/settings`,
`/playlists`, `/import`, `/onboarding`. Arguments are passed via `state.extra` as typed objects
(e.g. `PlayerArgs`, `VodItem`, `Series`).

Player controller in the `/player` route: `VideoPlayerControllerAdapter` (fvp)
on every platform — see `lib/features/player/CLAUDE.md`.

## result.dart — Result Type

```dart
sealed class Result<T>   // variants: Ok<T>(value), Err<T>(failure)
```

`Failure(message, {cause})` carries a human-readable message plus the optional raw exception.
Callers switch via `.when(ok: (v) => …, err: (f) => …)`. All repository methods that can fail
return `Result<T>`.

## debug_flags.dart — Compile-time Flags

```dart
const bool kFvpCaptureBuild = bool.fromEnvironment('FVP_CAPTURE'); // default: false
```

Enable with `--dart-define=FVP_CAPTURE=true`. Attaches a root `Logger` listener so MDK (fvp)
logs reach logcat, and asks MDK for `logLevel: all`. Off in all shipping/CI builds. Built for the
wang-bin/fvp#374 investigation, kept for player diagnostics — it is the only debug flag left.

## widgets/ — TV-Focused Reusable Widgets

- **`AdaptiveShell`** — `NavigationRail` (≥700 px wide, TV/desktop) vs `NavigationBar` (phone).
  GOTCHA: D-pad focus does NOT cross `FocusScope` boundaries automatically; `AdaptiveShell`
  intercepts LEFT/RIGHT arrow keys to hop focus between the rail scope and the body scope.
  Do not add nested `FocusScope` nodes inside branch screens without testing D-pad traversal.
- **`FocusableButton`** — draws a 3 px focus ring via `foregroundDecoration` (no layout impact)
  and scales to 1.04 on focus. Handles Enter, Space, Select, and GameButtonA. Pass
  `reduceMotion` from `AccessibilityCubit` state.
- **`PosterCard`** — 2:3 artwork tile. The favorite heart overlay is intentionally NOT a
  D-pad focus stop; tab/D-pad grid movement skips it.
- **`ContentRail`** / **`LiveBadge`** — horizontal scrolling rail and live indicator badge.
- **`NoorBreakpoints.rail = 700`** — single breakpoint constant; use it, don't hardcode 700.

## theme/ — Design Tokens

`buildTheme(palette, hyperlegible, rtl)` returns `ThemeData`. Raw tokens not covered by
`ColorScheme` (e.g. `dim`, `border`, `focus`, `live`) live in `AppPalette` and are accessed via
`context.palette.<token>` (extension on `BuildContext` backed by `PaletteExt` theme extension).

## a11y/ — Accessibility

`AccessibilitySettings` (freezed) holds: `textScale`, `reduceMotion`, `highContrast`,
`colorblindSafe`, `hyperlegibleFont`, captions (on/size/bgOpacity/color). Persisted by
`AccessibilityCubit`. Always thread `reduceMotion` into `FocusableButton`.

## i18n/ — Internationalisation

`LocaleCubit` (HydratedBloc) persists en/ar toggle. When `ar` is active, `localizeDigits(str, rtl: true)` converts ASCII digits to Arabic-Indic (٠١٢…) for display. RTL layout is handled by Flutter's directionality; `buildTheme` receives `rtl` to mirror typography spacing.
