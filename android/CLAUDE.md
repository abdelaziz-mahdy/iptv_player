# Android — Build & Renderer Notes

## App identity
- **namespace / applicationId**: `com.iptvplayer` (`android/app/build.gradle.kts`)
- **TV launcher**: `android:banner="@drawable/tv_banner"` in `<application>` — required for the Leanback (Android TV) home screen
- **Toolchain**: JDK 17, compileSdk 36, minSdk/targetSdk delegate to `flutter.*` defaults

## THE BIG GOTCHA — renderer

The manifest forces **Skia** via:
```xml
<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="false" />
```

**Why Skia, not Impeller?**  
Flutter's default Impeller backend uses Vulkan. On PowerVR TV GPUs Vulkan causes UI flicker and broken renders (flutter#165983, flutter#177319, flutter#161316). The OpenGLES Impeller backend is *not* a workaround — Flutter 3.44.2 silently ignores `ImpellerBackend=opengles` and still selects Vulkan on these devices (verified on-device). Skia/OpenGLES is the only stable non-Vulkan path.

**Do not re-enable Impeller** unless testing after a Flutter engine upgrade or a TV firmware update that fixes Vulkan support.

## Switching renderer: `scripts/set_impeller.py`

```
python3 scripts/set_impeller.py skia      # current production setting
python3 scripts/set_impeller.py opengles  # Impeller + GLES hint (ignored by 3.44.2)
python3 scripts/set_impeller.py vulkan    # Impeller + Vulkan (breaks PowerVR)
```

The script strips any existing `EnableImpeller`/`ImpellerBackend` meta-data tags and rewrites them before the `<activity>` anchor. Safe to run multiple times.

## Building & installing on TV

```
flutter build apk --release
scripts/install_on_tv.sh          # see scripts/CLAUDE.md for details
```

Convention: **install only, do not auto-launch** — let the user open the app on the TV.

## Video player

`fvp`/MDK is the video player. `MainActivity.kt` sets `EGL_SDR_DEPTH=8` in
`onCreate()` **before** `super.onCreate()` (fvp#374 — MDK's 10-bit surface
corrupts on PowerVR); it only affects the GL path, which the `tunnel` mode
bypasses, but stays for the fallback. Full story:
`lib/features/player/CLAUDE.md`.
