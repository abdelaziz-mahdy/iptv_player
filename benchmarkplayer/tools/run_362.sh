#!/usr/bin/env bash
# mdk-sdk#362: on a live stream whose timestamps start far from zero, MDK's
# OpenSL renderer sometimes starts the master clock at 0 instead of the
# stream's own base. Video is paced off that clock, so it advances at ~4% of
# real time (24fps content presents at about 1fps) while audio sounds normal.
#
# It is a start-up race, not a property of the stream — it hit 3 of 5 opens in
# the original report and 0 of 13 later on the same build. So a single open
# proves nothing: this repeats N opens and reports the split.
#
# Per open it records:
#   delta   from MDK's "1st audio frame ... delta:" line. Near zero = the clock
#           adopted the stream's timestamp base. Large negative (order -7.8e6)
#           = it started at 0. This is the bug's signature.
#   rate    media position advanced / wall time elapsed, from BENCH_STATS.
#           ~1.0 is correct; ~0.04 is the failure.
#
#   tools/run_362.sh <adb-serial> [opens] [seconds-per-open]
set -uo pipefail
cd "$(dirname "$0")/.."

S="${1:?adb serial}"
N="${2:-6}"
SECS="${3:-25}"
PKG="com.iptvplayer.benchmark_player"
URL="${BENCH_URL:-http://192.168.2.15:8000/live/stream.m3u8}"
OUT="bench-results/362"
mkdir -p "$OUT"
adb() { command adb -s "$S" "$@"; }

[[ "$S" == *:* ]] && adb connect "$S" >/dev/null 2>&1 || true
echo "== $N opens x ${SECS}s : $URL"
printf '%-6s %-16s %-8s %-10s %s\n' open delta rate verdict position-samples

BAD=0
for i in $(seq 1 "$N"); do
  LOG="$OUT/open-$i.log"
  adb shell am force-stop "$PKG" >/dev/null 2>&1
  adb shell input keyevent 224 >/dev/null 2>&1
  adb logcat -b all -c >/dev/null 2>&1
  sleep 2
  adb logcat -b all -v brief > "$LOG" 2>&1 &
  CAP=$!
  adb shell am start -n "$PKG/.MainActivity" --es bench_url "$URL" >/dev/null 2>&1
  sleep "$SECS"
  kill "$CAP" 2>/dev/null
  sleep 1

  DELTA=$(grep -aoE '1st audio frame.*delta: -?[0-9]+' "$LOG" | grep -oE 'delta: -?[0-9]+' | head -1 | awk '{print $2}')
  python3 tools/clock_rate.py "$LOG" > "$OUT/rate-$i.env"
  . "$OUT/rate-$i.env"

  V=ok
  case "$RATE" in
    na) V="no-stats" ;;
    *) awk "BEGIN{exit !($RATE < 0.5)}" && { V=BAD; BAD=$((BAD+1)); } ;;
  esac
  printf '%-6s %-16s %-8s %-10s %s\n' "$i" "${DELTA:-none}" "$RATE" "$V" "$SAMPLES"
done

echo
echo "== $BAD / $N opens showed the slow clock"
echo "   logs: $OUT/open-*.log"
