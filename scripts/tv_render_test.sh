#!/usr/bin/env bash
# Test ONE render config end-to-end: build+install, confirm backend, record a
# grid scroll AND a video playback, capture decoder/errors, and append a
# markdown section to the report file.
#   Usage: scripts/tv_render_test.sh <serial> <vulkan|opengles|skia> <report.md>
set -uo pipefail
S="${1:?serial}"; MODE="${2:?mode}"; REPORT="${3:?report path}"
PKG=com.iptvplayer
OUT=/tmp/render_${MODE}
adb() { command adb -s "$S" "$@"; }
k()   { adb shell input keyevent "$1" >/dev/null 2>&1; sleep "${2:-0.4}"; }
log() { echo "$@"; }

log "== [$MODE] manifest + build =="
python3 scripts/set_impeller.py "$MODE" >/dev/null
if ! flutter build apk --release >"/tmp/build_$MODE.log" 2>&1; then
  { echo; echo "## $MODE — BUILD FAILED"; echo '```'; tail -8 "/tmp/build_$MODE.log"; echo '```'; } >>"$REPORT"
  exit 1
fi
adb install -r build/app/outputs/flutter-apk/app-release.apk >/dev/null 2>&1
log "installed"

log "== launch + confirm backend =="
adb shell am force-stop $PKG; adb logcat -c
adb shell am start -n $PKG/.MainActivity >/dev/null 2>&1
until adb shell dumpsys window 2>/dev/null | grep mCurrentFocus | grep -q noor; do sleep 1; done
sleep 4
BACKEND=$(adb logcat -d 2>/dev/null | grep -iE "Using the .*rendering backend" | head -1 | sed 's/.*Using/Using/')
FVPMETA=$(adb logcat -d 2>/dev/null | grep -iE "FvpPlugin: metaData" | head -1 | sed 's/.*metaData/metaData/')

log "== navigate to Movies grid =="
k 21 0.5; for _ in 1 2 3 4 5 6; do k 19 0.25; done   # rail -> Home
k 20; k 20; k 20; k 23 0.8; k 22 0.6                  # -> Movies -> grid

log "== record grid scroll (9s) =="
adb shell screenrecord --size 1280x720 --bit-rate 5000000 --time-limit 9 /sdcard/g.mp4 &
REC=$!; end=$((SECONDS+8))
while [ $SECONDS -lt $end ]; do k 20 0.25; k 22 0.25; k 20 0.25; done
wait $REC 2>/dev/null
adb pull /sdcard/g.mp4 "${OUT}_grid.mp4" >/dev/null 2>&1
adb exec-out screencap -p > "${OUT}_grid.png" 2>/dev/null

log "== open a video =="
adb logcat -c
k 23 1.5        # open focused poster -> details
k 23 3.0        # Play (details autofocuses Play) -> player
adb exec-out screencap -p > "${OUT}_player.png" 2>/dev/null

log "== record playback (10s) =="
adb shell screenrecord --size 1280x720 --bit-rate 6000000 --time-limit 10 /sdcard/v.mp4 &
REC=$!
wait $REC 2>/dev/null
adb pull /sdcard/v.mp4 "${OUT}_video.mp4" >/dev/null 2>&1
adb exec-out screencap -p > "${OUT}_player2.png" 2>/dev/null

DECODER=$(adb logcat -d 2>/dev/null | grep -iE "decoder.video|MediaCodec.*decoder|create .*decoder|AMediaCodec|FFmpeg" | head -3 | tr '\n' ';')
VKERR=$(adb logcat -d 2>/dev/null | grep -icE "VK_ERROR|validation layer|vulkan.*error")
PLAYERR=$(adb logcat -d 2>/dev/null | grep -iE "PlatformException|media open|Source error|ExoPlaybackException|UnrecognizedInputFormat" | head -3 | tr '\n' ';')

# back out to a clean state for the next run
k 4 0.6; k 4 0.6; k 4 0.6

{
  echo
  echo "## Config: $MODE"
  echo "- **Backend:** ${BACKEND:-<not detected>}"
  echo "- **fvp meta:** ${FVPMETA:-<none>}"
  echo "- **Decoder lines:** ${DECODER:-<none>}"
  echo "- **Vulkan errors in log:** $VKERR"
  echo "- **Playback errors:** ${PLAYERR:-none}"
  echo "- **Artifacts:**"
  echo "  - grid video: \`${OUT}_grid.mp4\`  | still: \`${OUT}_grid.png\`"
  echo "  - video clip: \`${OUT}_video.mp4\` | stills: \`${OUT}_player.png\`, \`${OUT}_player2.png\`"
  echo "- **Grid flicker (observe TV):** ____"
  echo "- **Video artifacts (observe TV):** ____"
} >>"$REPORT"
log "== [$MODE] done =="
