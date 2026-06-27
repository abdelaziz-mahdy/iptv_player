#!/usr/bin/env bash
# Deep Android TV diagnostics for diagnosing/fixing a Flutter Impeller render
# bug (and for filing a flutter/flutter issue).
#   Usage: scripts/tv_diag.sh <adb-serial>     e.g. 192.168.2.20:5555
set -uo pipefail
S="${1:?usage: tv_diag.sh <adb-serial>}"
PKG="com.iptvplayer"
adb() { command adb -s "$S" "$@"; }
hr() { printf '\n===== %s =====\n' "$1"; }

hr "DEVICE"
for p in ro.product.manufacturer ro.product.model ro.product.name \
         ro.product.device ro.product.board ro.board.platform \
         ro.build.version.release ro.build.version.sdk \
         ro.build.version.security_patch ro.build.fingerprint \
         ro.hardware ro.hardware.egl ro.hardware.vulkan \
         ro.soc.manufacturer ro.soc.model \
         ro.gfx.driver.0 ro.gfx.driver.1 \
         debug.hwui.renderer persist.graphics.egl; do
  printf '%-34s %s\n' "$p" "$(adb shell getprop $p 2>/dev/null | tr -d '\r')"
done

hr "GPU / EGL / GLES (SurfaceFlinger)"
adb shell dumpsys SurfaceFlinger 2>/dev/null \
  | grep -iE "GLES:|EGL implementation|EGL_VERSION|DisplayManager|refresh" | head -8

hr "GPU DRIVER (dumpsys gpu)"
adb shell dumpsys gpu 2>/dev/null | head -40

hr "GRAPHICS FEATURES (Vulkan / OpenGL)"
adb shell pm list features 2>/dev/null | grep -iE "vulkan|opengl|hardware.gpu"

hr "DISPLAY MODES"
adb shell dumpsys display 2>/dev/null | grep -iE "mBaseDisplayInfo|refreshRate|FLAG_|deviceProductInfo" | head -10

hr "RENDERER / IMPELLER (from logcat — run the app first)"
adb logcat -d 2>/dev/null \
  | grep -iE "impeller|FvpPlugin: metaData|ImpellerBackend|Using the|rendering backend|VK_ERROR|Vulkan|validation" \
  | tail -20

hr "FRAME / JANK STATS (dumpsys gfxinfo $PKG)"
# Run + interact with the app, THEN this — gives total frames, jank %, histogram.
adb shell dumpsys gfxinfo "$PKG" 2>/dev/null \
  | grep -iE "Total frames|Janky frames|50th|90th|95th|99th|Number Missed Vsync|HISTOGRAM" | head -12

hr "GPU MEMORY (dumpsys gfxinfo $PKG / meminfo)"
adb shell dumpsys gfxinfo "$PKG" 2>/dev/null | grep -iE "Total GPU memory|EGL mTrimMemory" | head -4

hr "FOCUSED WINDOW"
adb shell dumpsys window 2>/dev/null | grep mCurrentFocus | tr -d '\r'
