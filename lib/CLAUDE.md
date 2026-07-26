# lib/ — Dart source architecture

## Three layers

| Dir | Role |
|---|---|
| `core/` | Shared infra: theme, router, DI, reusable widgets, a11y, i18n, `Result<T>` |
| `data/` | Sources → drift DB → repositories → models (no UI) |
| `features/` | One folder per screen/flow; each owns its Cubit + widgets |

## Entry point

`main.dart` → `configureProductionDependencies()` → `runApp(NoorApp())` → `SyncService.syncActive()` (background).
Video: fvp/MDK backing `video_player` on every platform (see `features/player/CLAUDE.md`).

`app.dart` wraps `MaterialApp.router` in `MultiBlocProvider` for `AccessibilityCubit` and `LocaleCubit`.

## State management

`flutter_bloc` / Cubit everywhere. Persisted state uses `HydratedCubit` (from `hydrated_bloc`) — currently `LocaleCubit` and `AccessibilityCubit`. Storage is initialised in `main()` before `runApp`.

## Navigation

`go_router` defined in `core/router/app_router.dart`.
Shell tabs: `StatefulShellRoute.indexedStack` (six tabs, state preserved across tab switches).
Pushed routes (player, details, import, etc.) use typed arg classes (`PlayerArgs`, etc.) defined at the top of `app_router.dart`.

## Dependency injection

`get_it` global `sl` in `core/di/injection.dart`.

- `configureDependencies()` — in-memory fakes; used by widget tests.
- `configureProductionDependencies()` — drift-backed impls; called by `main()`.

**GOTCHA:** `injectable` is in `pubspec.yaml` but **not used** — no `@injectable`/`@lazySingleton` annotations. Everything is registered manually with `registerLazySingleton` / `registerSingleton`. Do not add codegen-style annotations.

## Data access pattern

Repositories (defined as abstract classes in `data/repositories/repositories.dart`) return `Result<T>` (sealed class in `core/result.dart`). Pattern:

```dart
result.when(ok: (value) => ..., err: (failure) => ...);
```

Repositories **never throw** for expected failures — `Err(Failure(...))` instead. Live streams (channels, movies, favorites, continueWatching) return `Stream<List<…>>` — no `Result` wrapper.

## Codegen

`freezed` + `json_serializable` + `drift` tables all use `build_runner`.
`*.g.dart` and `*.freezed.dart` are **gitignored** — regenerate after schema/model changes:

```
dart run build_runner build --delete-conflicting-outputs
```

## Key `data/` layout

```
data/
  models/          # Freezed domain models + drift table definitions
  db/              # AppDatabase (drift), migration files
  sources/         # HTTP clients (Xtream, M3U parsers)
  repositories/
    repositories.dart       # abstract interfaces
    drift_repositories.dart # production impls
    fakes/                  # in-memory fakes for tests
  credential_store.dart / credential_store_drift.dart
```

## Key `core/` layout

```
core/
  di/injection.dart   # sl (GetIt), configureDependencies, configureProductionDependencies
  router/app_router.dart
  result.dart         # Result<T>, Ok<T>, Err<T>, Failure
  theme/              # AppTheme, AppPalette (standard + highContrast)
  a11y/               # AccessibilityCubit (HydratedCubit)
  i18n/               # LocaleCubit (HydratedCubit); ARB files in lib/l10n/
  widgets/            # Shared widgets, AdaptiveShell (tab shell)
  sync_service.dart   # Background playlist refresh
  debug_flags.dart    # kFvpCaptureBuild etc.
```
