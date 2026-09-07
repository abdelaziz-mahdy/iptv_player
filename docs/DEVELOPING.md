# Developing

Engineering notes for working on IPTV Player. For what the app is and how to
use it, see [README.md](../README.md).

## Getting started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generated code
flutter run            # pick a device
```

Requirements: Flutter **3.44.2** (stable), Dart 3.12+, JDK 17, Android SDK 36.

## Testing

```bash
flutter analyze
flutter test
```

Both must be clean before a commit.

### Screenshots

`tools/screenshot_tour.sh` renders the README images from the real app against
demo data, at three widths (TV, desktop, phone). It needs a directory of
generated artwork:

```bash
DEMO_ART_DIR=<artwork-dir> tools/screenshot_tour.sh
```

Everything it renders is fictional — invented titles and generated gradients —
so no real provider catalogue ends up in a public repo.

## Build release artifacts

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

Diagnostics/automation helpers for TV debugging live in `scripts/` and
[TV_DEBUG.md](TV_DEBUG.md).

## Tech stack

- **State:** `flutter_bloc` / Cubit, `hydrated_bloc`, `equatable`
- **Navigation:** `go_router` (`StatefulShellRoute.indexedStack`)
- **DI:** `get_it` + `injectable`
- **Persistence:** `drift` (SQLite) with schema migrations
- **Models/codegen:** `freezed` + `json_serializable` + `build_runner`
- **Data:** `xtream_code_client`, `m3u_nullsafe`, `xml` (XMLTV), `dio`
- **Video:** `fvp` (MDK) backing `video_player` on every platform
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

- **Video corruption** with `fvp`/MDK's GL renderer on PowerVR: the driver
  advertises RGBA_1010102 window configs but marks them all non-conformant, and
  rendering into one corrupts the picture (reproduces with every decoder, even
  software — decoding is fine, the renderer isn't). Fixed by falling back to an
  8-bit render target. Upstream: wang-bin/fvp#374, PR #385.

- **4K on TV** needs the decoder to bypass the GL renderer entirely
  (`tunnel: true` + `VideoViewType.platformView`): MediaCodec writes into the
  SurfaceView's buffer queue, so the video scans out at panel resolution while
  the UI layer stays at 1080p. Measured on a Realtek TV: 24.0 fps at 4K24 and
  56.3 fps at 4K60, against ~22 through the GL platform view and 10.9 through
  the Flutter texture. Upstream: wang-bin/fvp#379.

- **Audio backend drives frame pacing.** MDK slaves video timing to the audio
  clock; this TV's AAudio reported positions too coarsely and frames presented
  in bursts at ~10 fps. The app asks for OpenSL (`audio.renderer`) until the
  AAudio fixes reach a released SDK. Upstream: wang-bin/fvp#384.

Related upstream issues: flutter#177319, flutter#165983, flutter#161316.

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
