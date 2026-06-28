<div align="center">

# IPTV Player

A real IPTV client for **Android (phone + TV)** and **desktop (macOS / Windows / Linux)**, built with Flutter.

Xtream Codes • M3U / M3U8 • XMLTV EPG • real playback via libmpv (media_kit / fvp)

</div>

---

> **Status:** early development. This app hosts **no content** — all channels and
> media come from playlists **you** provide.

## Features

- **Sources**
  - **Xtream Codes** portals (live, VOD, series, categories, EPG)
  - **M3U / M3U8** playlists (URL or file)
  - **XMLTV** EPG parsing
- **Playback** via libmpv — [`media_kit`](https://pub.dev/packages/media_kit) on
  Android, [`fvp`](https://pub.dev/packages/fvp) on desktop — handling the wide
  range of codecs/containers IPTV streams use that native players often can't,
  with hardware decoding. Live/VOD aware, real-time bitrate badge, auto-hiding
  controls.
- **Continue Watching** — VOD resumes where you left off. The position is saved
  continuously during playback and when the app is backgrounded, so it survives
  the app being closed from the Home button or killed by the TV.
- **TV-first UX** — full D-pad navigation, on-screen focus rings, native TV text
  entry, a side rail reachable with LEFT, and a leanback launcher banner.
- **Library** — Home rails, Live TV (groups → channels → player), Movies & Series
  grids (on-demand seasons/episodes) with real category names, Favorites, Search.
- **Accessibility** — text scaling, reduce-motion, high-contrast palette, captions,
  RTL + Arabic-Indic numerals, screen-reader semantics.

## Platforms

| Platform | Status | Notes |
|---|---|---|
| Android phone | ✅ | |
| Android TV | ✅ | leanback launcher + D-pad; see renderer note below |
| macOS | ✅ | |
| Windows | ✅ | |
| Linux | ✅ | |
| iOS / Web | ❌ | not targeted |

## Tech stack

- **State:** `flutter_bloc` / Cubit, `hydrated_bloc`, `equatable`
- **Navigation:** `go_router` (`StatefulShellRoute.indexedStack`)
- **DI:** `get_it` + `injectable`
- **Persistence:** `drift` (SQLite) with schema migrations
- **Models/codegen:** `freezed` + `json_serializable` + `build_runner`
- **Data:** `xtream_code_client`, `m3u_nullsafe`, `xml` (XMLTV), `dio`
- **Video:** libmpv — `media_kit` (Android), `fvp` backing `video_player` (desktop)
- **Fonts:** bundled Hanken Grotesk (variable), IBM Plex Sans Arabic, Atkinson Hyperlegible

## Android TV renderer & video notes

On some Android TV GPUs (notably **PowerVR**) two *separate* rendering problems
appear; both are worked around here:

- **UI flicker** under Flutter's default **Impeller (Vulkan)** backend. The app
  forces **Skia** via `AndroidManifest.xml` (confirmed stable on TCL/PowerVR).
  Impeller's OpenGLES backend is **not** an escape hatch — Flutter 3.44.2 ignores
  `ImpellerBackend=opengles` and still uses Vulkan. Helper:
  `scripts/set_impeller.py {vulkan|opengles|skia}`.

  ```xml
  <meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />
  ```

- **Video corruption** with `fvp`/MDK's GL renderer (reproduces with every
  decoder, even software — decoding is fine, the renderer isn't). Android
  therefore plays via **`media_kit`** (mpv `vo_gpu`), which renders the same
  streams correctly on the same GPU; desktop keeps `fvp`, where it works.
  Upstream: wang-bin/fvp#374.

Related upstream issues: flutter#177319, flutter#165983, flutter#161316.

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generated code
flutter run            # pick a device
```

Requirements: Flutter **3.44.2** (stable), Dart 3.12+, JDK 17, Android SDK 36.

### Build release artifacts

```bash
flutter build apk --release        # Android (build/app/outputs/flutter-apk/)
flutter build appbundle --release  # Android App Bundle
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

> Release APKs are currently **debug-signed** for easy sideloading. Wire a real
> signing config before publishing.

### App icon

Sources live in `assets/icon/`. Regenerate launcher icons with:

```bash
dart run flutter_launcher_icons
```

## Deploying to an Android TV on your LAN

No store needed — sideload over the local network:

```bash
flutter build apk --release
cd build/app/outputs/flutter-apk && python3 -m http.server 8000 --bind 0.0.0.0
```

On the TV, open the URL (e.g. `http://<your-ip>:8000/app-release.apk`) with the
**Downloader** app, or push directly over ADB:

```bash
adb connect <tv-ip>:5555
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Diagnostics/automation helpers for TV debugging live in `scripts/` and `docs/TV_DEBUG.md`.

## Testing

```bash
flutter analyze
flutter test
```

## Project layout

```
lib/
  core/        theme, router, DI, widgets (AdaptiveShell, FocusableButton, PosterCard), a11y
  data/        sources (xtream/m3u/xmltv), drift db, repositories, models
  features/    home, live, grid, details, player, search, favorites, settings, import, ...
  l10n/        ARB + generated localizations
packages/
  flutter_android_tv_text_field/   vendored MIT fork — native TV D-pad text input
docs/          specs, plans, TV debug guide
scripts/       TV diagnostics / render-config helpers
```

### Vendored fork

`packages/flutter_android_tv_text_field` is a vendored, MIT-licensed fork (© Talha
Yasir) that fixes the build against current toolchains and makes the focus border
themable. It works around Flutter's Android-TV `TextField` D-pad bug (flutter#147772).

## Releases / CI

Pushing a `v*` tag (e.g. `v1.0.0`) triggers GitHub Actions to build and attach
artifacts to a GitHub Release. See `.github/workflows/`.

```bash
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

## License & disclaimer

This application does not provide, host, or distribute any media. It is a player
for playlists supplied by the user. Ensure you have the right to access any content
you load.
