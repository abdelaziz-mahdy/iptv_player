# scripts/ — helper scripts for AI agents & developers

All scripts run from the **repo root**.

## Scripts (git-tracked only)

| Script | What it does |
|---|---|
| `install_on_tv.sh [apk\|variant]` | Discovers Android TVs via mDNS + existing adb connections, lets you pick one, connects, and installs an APK. Variant shortcuts: `opengles` (default), `skia`, `release`, `image0`, `tunnel`, `sw`, `exo`, `mediakit`. |
| `set_impeller.py <mode>` | Rewrites `android/app/src/main/AndroidManifest.xml` renderer meta-data. Modes: `vulkan` (Impeller+Vulkan), `opengles` (Impeller+GLES), `skia` (Impeller disabled). |
| `set_fvp.py <mode>` | Patches `fvp.registerWith(options:{...})` in `lib/features/player/video_controller.dart` to swap the Android decode/render path. Modes: `copy`, `image0`, `surface0`, `tunnel`, `sw`, `exo`, `diag`. |
| `tv_diag.sh <serial>` | Dumps deep GPU/EGL/Vulkan/display diagnostics from a connected TV (device props, SurfaceFlinger, GPU driver, features, recent Impeller logcat). |
| `tv_capture.sh <serial> <label> [secs]` | Resets frame stats, screen-records while injecting D-pad scrolling, pulls the video, and prints jank/percentile stats. |
| `tv_render_test.sh <serial> <mode> <report.md>` | Full end-to-end for one render config: sets manifest via `set_impeller.py`, builds release APK, installs, auto-navigates to Movies grid, records grid scroll + video playback, captures decoder/error logs, appends a Markdown section to the report. |
| `tv_render_all.sh <serial>` | Runs `tv_render_test.sh` for all three modes (`vulkan`, `opengles`, `skia`) in sequence, then restores `AndroidManifest.xml` via `git checkout`. |

## Example invocations

```bash
# Install the default (opengles) APK onto the TV
scripts/install_on_tv.sh

# Install a specific variant
scripts/install_on_tv.sh skia

# Switch manifest to Skia renderer, then build
python3 scripts/set_impeller.py skia
flutter build apk --release --flavor skia

# Switch fvp to copy=1 (AMediaCodec copy path — fixes PowerVR corruption)
python3 scripts/set_fvp.py copy

# Dump TV diagnostics
scripts/tv_diag.sh 192.168.2.17:5555

# Record a 15-second jank-capture session
scripts/tv_capture.sh 192.168.2.17:5555 impeller-vulkan 15

# Full 3-way render sweep + report
scripts/tv_render_all.sh 192.168.2.17:5555
```

## GOTCHAS

**Deploy = install only, never auto-launch.**
The user opens the app themselves after install. `adb install -r` is the correct last step.
Never call `adb shell am start` as part of a deploy — only `tv_render_test.sh` launches the app because it needs to observe the running renderer, and that is a diagnostic workflow, not a normal deploy.

**Network adb endpoint:** typically `192.168.2.17:5555`. Rediscover with:
```bash
adb mdns services
```

**Renderer choice for this device (PowerVR TV):**
Impeller+Vulkan and plain GLES both flicker on the PowerVR GPU. **Skia** (`set_impeller.py skia`) is the stable renderer. On the video side, **fvp/MDK** decodes straight into a SurfaceView (`tunnel`), the only path that sustains 4K here; MDK's GL renderer corrupts video on PowerVR, worked around with an 8-bit render target (fvp#374).

**`set_impeller.py` / `set_fvp.py` mutate tracked files.**
Always restore with `git checkout -- <file>` after diagnostic sweeps (or use `tv_render_all.sh` which does this automatically for the manifest).
