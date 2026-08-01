#!/usr/bin/env bash
# Play one clip in the installed bench APK and report whether the decoder is
# actually presenting frames. Built for mdk-sdk#361 (direct-surface output
# wedges on some content): the failure is silent — audio and position keep
# running while zero output buffers are released — so "it looks black" is not
# evidence and a screenshot is useless (the video plane is not in screencap).
#
# What it measures:
#   presented fps  SurfaceFlinger frame timestamps on the app's SurfaceView
#   QIB / ROB      MDK's queued-input vs released-output buffer counters.
#                  QIB climbing with ROB stuck at 0 IS the wedge.
#
#   tools/run_clip.sh <adb-serial> <url> [label] [seconds]
set -uo pipefail
cd "$(dirname "$0")/.."

S="${1:?adb serial}"
URL="${2:?clip url}"
LABEL="${3:-clip}"
SECS="${4:-25}"
PKG="com.iptvplayer.benchmark_player"
OUT="bench-results/361"
mkdir -p "$OUT"
adb() { command adb -s "$S" "$@"; }

[[ "$S" == *:* ]] && adb connect "$S" >/dev/null 2>&1 || true

echo ">> $LABEL: $URL"
adb shell input keyevent 224 >/dev/null 2>&1
adb shell am force-stop "$PKG" >/dev/null 2>&1
adb logcat -b all -c >/dev/null 2>&1
sleep 1
# Stream logcat from before launch: MDK runs at logLevel=all here and the
# ring buffer wraps within seconds, so a `logcat -d` afterwards loses the
# decoder-open lines that say whether direct-to-surface actually engaged.
adb logcat -b all -v brief > "$OUT/$LABEL.log" 2>&1 &
CAP=$!
adb shell am start -n "$PKG/.MainActivity" --es bench_url "$URL" >/dev/null 2>&1

# Measure steady state, not the open: wait for a stats line reporting
# buffering=false before starting the clock, else the ramp-up drags the
# average down and a slow start reads as a decoder problem.
echo -n "   waiting for steady state"
for i in $(seq 1 30); do
  sleep 2
  if grep -aq 'BENCH_STATS.*buffering=false' "$OUT/$LABEL.log" 2>/dev/null; then
    echo " ok (${i}x2s)"; break
  fi
  echo -n "."
  [ "$i" = 30 ] && echo " TIMEOUT - never left buffering"
done

# The app has several SurfaceView layers (Flutter's own plus the platform
# view's, each with a BLAST twin). Which one the decoder feeds is not fixed, so
# clear and sample them all and keep whichever actually carries frames.
# macOS ships bash 3.2 - no mapfile, so the layer list goes through a file.
adb shell dumpsys SurfaceFlinger --list 2>/dev/null \
  | grep -F "SurfaceView[$PKG" | tr -d '\r' > "$OUT/$LABEL-layers.txt"
echo "   candidate layers: $(wc -l < "$OUT/$LABEL-layers.txt" | tr -d ' ')"
while IFS= read -r L; do
  [ -n "$L" ] && adb shell dumpsys SurfaceFlinger --latency-clear "'$L'" >/dev/null 2>&1 </dev/null
done < "$OUT/$LABEL-layers.txt"
sleep "$SECS"
: > "$OUT/$LABEL-latency.txt"
BEST=0
while IFS= read -r L; do
  [ -z "$L" ] && continue
  adb shell dumpsys SurfaceFlinger --latency "'$L'" 2>/dev/null > "$OUT/$LABEL-tmp.txt" </dev/null
  N=$(awk 'NR>1 && $2!=0 && $2!="9223372036854775807"' "$OUT/$LABEL-tmp.txt" | wc -l | tr -d ' ')
  echo "     $L -> $N frames"
  if [ "$N" -gt "$BEST" ]; then BEST=$N; cp "$OUT/$LABEL-tmp.txt" "$OUT/$LABEL-latency.txt"; fi
done < "$OUT/$LABEL-layers.txt"
rm -f "$OUT/$LABEL-tmp.txt"
adb exec-out screencap -p > "$OUT/$LABEL.png" 2>/dev/null
kill "$CAP" 2>/dev/null; sleep 1

python3 - "$OUT/$LABEL-latency.txt" "$SECS" <<'PY'
import sys
rows=[]
for ln in open(sys.argv[1]).read().split('\n')[1:]:
    p=ln.split()
    if len(p)==3:
        try:
            v=int(p[1])
            if v and v!=9223372036854775807: rows.append(v)
        except ValueError: pass
if len(rows)>1:
    span=(rows[-1]-rows[0])/1e9
    print("   presented: %d frames, %.1fs, %.2f fps" % (len(rows), span, (len(rows)-1)/span))
else:
    print("   presented: %d frames in %ss  <-- NO OUTPUT" % (len(rows), sys.argv[2]))
PY

LOG="$OUT/$LABEL.log"
echo "   QIB(input queued) lines: $(grep -ac 'QIB' "$LOG" 2>/dev/null)   ROB(output released) lines: $(grep -ac 'ROB' "$LOG" 2>/dev/null)"
echo "   last stats: $(grep -a 'BENCH_STATS' "$LOG" | tail -1 | sed 's/.*BENCH_STATS] //')"
echo "   codec: $(grep -a 'AMediaCodec selected video codec name' "$LOG" | tail -1 | sed 's/.*name: //')"
echo "   decoder cfg: $(grep -aoE 'tunnel: [0-9]+, window: [^,]+, surface: [^,]+' "$LOG" | tail -1)"
grep -aoE 'hdr-static-info|android\._dataspace: int32\([0-9]+\)|color-transfer: int32\([0-9]+\)' "$LOG" | sort -u | sed 's/^/   /' | head -5
echo "   decode errors: $(grep -acE 'decode error|can not return buffer|dequeue.*-10000' "$LOG" 2>/dev/null)"
echo "   -> $LOG"
