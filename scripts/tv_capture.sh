#!/usr/bin/env bash
# Captures a grid-scroll session for one render config: resets frame stats,
# records the screen while injecting D-pad scrolling, then pulls the video and
# prints jank stats. Run AFTER navigating the app to a content grid.
#   Usage: scripts/tv_capture.sh <adb-serial> <config-label> [seconds]
#   e.g.  scripts/tv_capture.sh 192.168.2.20:5555 impeller-vulkan 12
set -uo pipefail
S="${1:?serial}"; LABEL="${2:?label, e.g. impeller-vulkan}"; SECS="${3:-12}"
PKG="com.iptvplayer"
OUT="/tmp/tv_${LABEL}"
adb() { command adb -s "$S" "$@"; }

echo ">> reset frame stats"
adb shell dumpsys gfxinfo "$PKG" reset >/dev/null 2>&1
adb logcat -c

echo ">> recording ${SECS}s to device while scrolling (D-pad down/up)"
adb shell screenrecord --time-limit "$SECS" --bit-rate 8000000 /sdcard/cap.mp4 &
REC=$!
# Inject scrolling so the capture is deterministic.
end=$((SECONDS + SECS - 1))
while [ $SECONDS -lt $end ]; do
  adb shell input keyevent 20 >/dev/null 2>&1   # DPAD_DOWN
  adb shell input keyevent 22 >/dev/null 2>&1   # DPAD_RIGHT
done
wait $REC 2>/dev/null

echo ">> pulling video -> ${OUT}.mp4"
adb pull /sdcard/cap.mp4 "${OUT}.mp4" 2>/dev/null

echo ">> jank stats (${LABEL}):"
adb shell dumpsys gfxinfo "$PKG" 2>/dev/null \
  | grep -iE "Total frames|Janky frames|Number Missed Vsync|50th|90th|95th|99th" \
  | tee "${OUT}_gfxinfo.txt"

echo ">> impeller/vulkan log lines:"
adb logcat -d 2>/dev/null \
  | grep -iE "impeller|ImpellerBackend|VK_ERROR|validation|rendering backend" \
  | tail -10
