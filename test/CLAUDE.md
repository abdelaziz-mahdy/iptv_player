# test/ — Testing conventions

## Commands

```
flutter test               # full suite (301 tests, must stay green)
flutter test <path>        # single file
flutter analyze            # must be clean before any commit
```

## Structure

Mirrors `lib/`: `test/features/…`, `test/data/…`, `test/core/…`.

## Fakes — never real network or DB

All tests use in-memory fakes injected directly into cubits:

| Fake | Lives in |
|---|---|
| `FakePlaylistRepository`, `FakeContentRepository`, `FakePlaybackRepository`, `FakeEpgRepository` | `lib/data/repositories/fakes/fake_repositories.dart` |
| `FakePlayerController` | `test/features/player/fake_player_controller.dart` |

Fakes seed realistic data (3 channels, 4 movies, 2 series, seeded playlist `p1`). `FakePlaybackRepository` starts empty — no pre-saved progress.

## GOTCHA: async stream binding

Content cubits subscribe to the active-playlist stream inside their `load()` / `start()` call. The subscription resolves in the next microtask, **not** synchronously. Always pump before asserting:

```dart
await cubit.load();
await Future<void>.delayed(Duration.zero); // let stream binding fire
expect(cubit.state.channels, isNotEmpty);
```

This pattern is used throughout `home_cubit_test.dart`, `favorites_cubit_test.dart`, `search_cubit_test.dart`, etc.

## GOTCHA: HydratedCubit tests need FakeHydratedStorage

`LocaleCubit` and `AccessibilityCubit` are `HydratedCubit`s. Tests that touch them (or any screen that wraps them) must call:

```dart
setUp(installFakeHydratedStorage); // from test/support/fake_hydrated_storage.dart
```

Widget tests also call `await configureDependencies()` (in-memory DI) + `await sl.reset()` in tearDown.

## PlayerCubit test hooks (avoid real Timer waits)

| Method | What it does |
|---|---|
| `hideControlsForTesting()` | Instantly hides controls, bypassing the auto-hide timer |
| `saveProgressNow()` | Fires the periodic progress checkpoint immediately |
| `pollBitrateBadgeForTesting()` | Triggers one bitrate-badge tick synchronously |

Prefer these over `await Future.delayed(realDuration)`.

## Progress rules (verified in player_cubit_test.dart)

- `MediaKind.channel` → progress is **never** saved (live streams).
- `MediaKind.movie` / `MediaKind.episode` → progress saved on `close()` and via `saveProgressNow()`.
