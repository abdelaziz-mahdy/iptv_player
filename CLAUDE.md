# IPTV Player — agent & contributor guide

A Flutter IPTV client for **Android (phone + TV)** and **desktop (macOS/Windows/Linux)**.
Xtream Codes / M3U / XMLTV sources, MDK (fvp) playback. The app hosts no content —
playlists are user-supplied.

This file is the **index**. Each major directory has its own `CLAUDE.md` with the
detail for that area — read the relevant one before working there.

## Directory map

| Area | Guide | What lives there |
|---|---|---|
| Dart source | [lib/CLAUDE.md](lib/CLAUDE.md) | architecture & layering overview |
| Shared infra | [lib/core/CLAUDE.md](lib/core/CLAUDE.md) | DI, router, theme, widgets, a11y, i18n, `Result`, debug flags |
| Data layer | [lib/data/CLAUDE.md](lib/data/CLAUDE.md) | sources, drift DB, repositories (+ fakes), models |
| Features | [lib/features/CLAUDE.md](lib/features/CLAUDE.md) | screen+cubit module pattern |
| Video player | [lib/features/player/CLAUDE.md](lib/features/player/CLAUDE.md) | fvp/MDK backend, direct-to-surface 4K, progress saving |
| Tests | [test/CLAUDE.md](test/CLAUDE.md) | fakes, async-binding gotcha, test hooks |
| Android | [android/CLAUDE.md](android/CLAUDE.md) | manifest, renderer (Skia), gradle |
| Scripts | [scripts/CLAUDE.md](scripts/CLAUDE.md) | TV install/diagnostic helpers |
| Vendored pkgs | [packages/CLAUDE.md](packages/CLAUDE.md) | native TV text-field fork |

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after model/db/freezed changes
flutter run                                                 # pick a device
flutter analyze && flutter test                             # must both be clean before commit
flutter build apk --release                                 # Android (build/app/outputs/flutter-apk/)
```

Requirements: Flutter **3.44.2** (stable), Dart 3.12+, JDK 17, Android SDK 36.

## Project-wide things that bite

- **Renderer = Skia on Android.** Impeller (Vulkan) flickers on PowerVR TV GPUs;
  OpenGLES Impeller is ignored by Flutter 3.44.2. Forced via AndroidManifest. See
  [android/CLAUDE.md](android/CLAUDE.md).
- **One video backend: `fvp`/MDK behind `video_player`.** On Android it decodes
  straight into a SurfaceView (`tunnel`), the only path that sustains 4K on TV
  hardware; MDK's GL renderer corrupts video on PowerVR (upstream fvp#374) and
  HDR stalls the decoder in direct mode (mdk-sdk#361). fvp is pinned to a fork
  branch — see [lib/features/player/CLAUDE.md](lib/features/player/CLAUDE.md).
- **Active playlist is a stream.** Feature cubits subscribe to
  `PlaylistRepository.active()` and re-bind on change — never read `.first` once
  (that caused "no content until restart"). See [lib/features/CLAUDE.md](lib/features/CLAUDE.md).
- **DI is manual** (`get_it` in `core/di/injection.dart`); `injectable` is unused.
- **Generated code is gitignored** (`*.g.dart`, `*.freezed.dart`) — run build_runner.
- **Data ops return `Result<T>`** (`Ok`/`Err`/`Failure`), not thrown exceptions.

## Conventions

- **Deploying to the TV: install only, never auto-launch** (`adb install -r`); the
  user opens the app themselves. Network adb at `192.168.2.17:5555`.
- **CHANGELOG.md is user-facing** — describe what changes for people using the app,
  not implementation steps, tooling, or repo housekeeping.
- **Releases use a `v` prefix** (`v1.0.0`); CI triggers on `v*` tags.
- **Git history is append-only** — new commits over amend; regular push over force-push.

## What never gets committed

Device logs, crash reports and build artifacts are **local diagnostics**. They
have leaked in twice, both times via a blanket `git add -A`: a pulled TV log
(`tv-logs/…/app-*.log`) and a Flutter crash report (`flutter_01.log`). Removing
them needed a history rewrite and a force-push — the one operation this repo
otherwise forbids.

- **Stage explicitly.** `git add <paths>`, not `git add -A`, unless you have
  just read `git status` and every entry belongs in the commit.
- **Never commit:** `tv-logs/`, `flutter_*.log`, `*.apk`, `mdk-sdk*.7z`,
  `bench-results/`, anything under `docs/issue-*/`. All are gitignored — keep
  it that way rather than un-ignoring for convenience.
- **Provider identity is sensitive, not just credentials.** `scrubUrl` masks
  username/password, so a log looks safe — but the server host
  (`http://<provider>/…`) and the playlist id stay in clear text and tie the
  user to their subscription. Treat any pulled log as private.
- **Upstream reports:** attach logs to the issue/PR, scrubbed, never to a
  commit. `scripts/pull_logs.sh` writes to the gitignored `tv-logs/`.
- **Before making a repo public**, scan history, not just the working tree:
  `git rev-list --all | while read c; do git grep -inE '<pattern>' $c -- .;
  done`. Working-tree greps miss everything already committed.
