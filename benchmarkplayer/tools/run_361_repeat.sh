#!/usr/bin/env bash
# mdk-sdk#361 is INTERMITTENT — the same clip wedges on some opens and plays on
# others. A single pass proves nothing (3 passes led me to call it fixed when it
# was not), so this repeats N opens and counts how many wedged.
#
# Wedge detection is differential, not a log grep: sample MediaCodec's counters
# twice, 6s apart, late in the run. Input still being queued while zero output
# buffers come back IS the wedge:
#   QIB rising + ROB rising  -> playing
#   QIB rising + ROB frozen  -> WEDGED
#   QIB frozen               -> not decoding at all (paused/ended/never started)
#
#   tools/run_361_repeat.sh <adb-serial> <url> [opens] [seconds-per-open]
set -uo pipefail
cd "$(dirname "$0")/.."

S="${1:?adb serial}"
URL="${2:?clip url}"
N="${3:-10}"
SECS="${4:-45}"
PKG="com.iptvplayer.benchmark_player"
OUT="bench-results/361-repeat"
mkdir -p "$OUT"
adb() { command adb -s "$S" "$@"; }

counters() {  # -> "<last QIB num> <last ROB num>"
  adb logcat -b all -d 2>/dev/null > "$1"
  local q r
  q=$(grep -aoE 'QIB num:[0-9]+' "$1" | tail -1 | grep -oE '[0-9]+')
  r=$(grep -aoE 'ROB num:[0-9]+' "$1" | tail -1 | grep -oE '[0-9]+')
  echo "${q:-0} ${r:-0}"
}

[[ "$S" == *:* ]] && adb connect "$S" >/dev/null 2>&1 || true
echo "== $N opens x ${SECS}s : $URL"
printf '%-6s %-16s %-16s %s\n' open "QIB in" "ROB out" verdict

WEDGED=0
for i in $(seq 1 "$N"); do
  adb shell am force-stop "$PKG" >/dev/null 2>&1
  adb shell input keyevent 224 >/dev/null 2>&1
  adb logcat -b all -c >/dev/null 2>&1
  sleep 2
  adb shell am start -n "$PKG/.MainActivity" --es bench_url "$URL" >/dev/null 2>&1
  sleep "$SECS"

  read -r Q1 R1 <<<"$(counters "$OUT/open-$i.log")"
  sleep 6
  read -r Q2 R2 <<<"$(counters "$OUT/open-$i.log")"

  DQ=$((Q2 - Q1)); DR=$((R2 - R1))
  if [ "$DQ" -gt 0 ] && [ "$DR" -eq 0 ]; then
    V=WEDGED; WEDGED=$((WEDGED + 1))
  elif [ "$DQ" -eq 0 ]; then
    V="idle(not decoding)"
  else
    V=ok
  fi
  printf '%-6s %-16s %-16s %s\n' "$i" "$Q1->$Q2 (+$DQ)" "$R1->$R2 (+$DR)" "$V"
done

echo
echo "== $WEDGED / $N opens wedged"
echo "   logs: $OUT/open-*.log"
