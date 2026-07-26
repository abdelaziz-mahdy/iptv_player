#!/usr/bin/env bash
# Repro for the MDK audio-clock bug on streams whose timestamps do not start
# at zero — a provider's live TS, or any file opened at a seek position.
#
# MDK sometimes starts the audio clock at 0 instead of the stream's own base.
# Video is paced against that clock, so every frame's pts is hours in the
# future and none is ever presented: frozen picture, audio playing normally.
# Reopening re-rolls it, which is why it reads as intermittent.
#
# SOURCE=live (default) uses the local HLS stream from tools/make_live.sh,
# which starts its timestamps at TS_OFFSET — the case seen on the TV.
# SOURCE=seek opens the plain clip and seeks to RESUME_AT instead.
#
# Each run is judged by two independent signals:
#   - MDK's own line, "1st audio frame (after seek) rendered: ... delta: N".
#     |delta| ~ 0 = clock took the stream's base (good); |delta| ~ base*1000 =
#     clock started at zero (bad).
#   - frames actually presented, from SurfaceFlinger. A bad run shows the audio
#     position advancing while the presented-frame count stays flat.
#
# Runs every audio backend so the report can say whether it is backend-specific.
# Texture view throughout — no platform view, so this is stock fvp behaviour.
#
# Usage: tools/resume_repro.sh [runs-per-backend]      (default 5)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERIAL="${SERIAL:-192.168.2.17:5555}"
APKDIR="$ROOT/bench-results/apks"
OUTDIR="${OUTDIR:-$ROOT/bench-results/resume-$(date +%F-%H%M)}"
PKG=com.iptvplayer.benchmark_player
RUNS="${1:-5}"
SOURCE="${SOURCE:-live}"
SEEK="${RESUME_AT:-300}"
HOST_IP="${HOST_IP:-$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')}"
URLBASE="${URLBASE:-http://$HOST_IP:8000}"
if [[ "$SOURCE" == live ]]; then
  URL="$URLBASE/live/stream.m3u8"
  SEEK=0
else
  URL="$URLBASE/bench-24fps.mp4"
fi
# Override to re-test a subset: BACKENDS="OpenSL AudioTrack" tools/resume_repro.sh 3
read -r -a BACKENDS <<< "${BACKENDS:-OpenSL AAudio AudioTrack default}"

mkdir -p "$OUTDIR" "$APKDIR"
echo "serial=$SERIAL source=$SOURCE url=$URL seek=${SEEK}s runs=$RUNS -> $OUTDIR"

build() { # $1=backend
  local b="$1" apk="$APKDIR/resume-$SOURCE-$1.apk" flags=()
  if [[ -f "$apk" && "$(cat "$apk.url" 2>/dev/null)" == "$URL|$SEEK" ]]; then
    echo "== $b: apk cached"; return
  fi
  flags=(--dart-define=BENCH_BACKEND=fvp --dart-define=BENCH_URL=$URL
         --dart-define=BENCH_SEEK=$SEEK --dart-define=BENCH_VARIANT=resume-$b)
  [[ "$b" != default ]] && flags+=(--dart-define=FVP_AUDIO_BACKEND=$b)
  echo "== $b: building"
  (cd "$ROOT" && flutter build apk --release "${flags[@]}" >/dev/null) || return 1
  cp "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$apk"
  echo "$URL|$SEEK" > "$apk.url"
}

# Newest present timestamp across every layer the app owns, in ns.
#
# Which layer carries the video differs by view type (Flutter window vs the
# platform view's own SurfaceView), and --latency on the wrong one returns
# nothing — so probe them all and take the newest. Counting rows would not
# work either: --latency returns a fixed-size window.
newest_present() {
  local layers ts best=0
  layers="$(adb -s "$SERIAL" shell dumpsys SurfaceFlinger --list 2>/dev/null \
    | tr -d '\r' | grep -F "$PKG")"
  while IFS= read -r l; do
    [[ -z "$l" ]] && continue
    ts="$(adb -s "$SERIAL" shell dumpsys SurfaceFlinger --latency "\"$l\"" 2>/dev/null \
      | tr -d '\r' \
      | awk 'NF==3 && $2!=0 && $2!~/922337203685477/ && $2+0>m {m=$2} END{print m+0}' </dev/null)"
    (( ${ts:-0} > best )) && best="${ts:-0}"
  done <<< "$layers"
  echo "$best"
}

summary="$OUTDIR/summary.txt"
: > "$summary"

for b in "${BACKENDS[@]}"; do
  build "$b" || { echo "!! $b: build failed" | tee -a "$summary"; continue; }
  adb -s "$SERIAL" install -r "$APKDIR/resume-$SOURCE-$b.apk" >/dev/null || continue

  for run in $(seq 1 "$RUNS"); do
    log="$OUTDIR/$SOURCE-$b-run$run.log"
    adb -s "$SERIAL" shell am force-stop "$PKG" >/dev/null 2>&1
    adb -s "$SERIAL" logcat -c >/dev/null 2>&1
    adb -s "$SERIAL" logcat -v time > "$log" 2>/dev/null &
    lpid=$!
    adb -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1
    adb -s "$SERIAL" shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1

    # Let it open, seek and settle.
    sleep 12
    p1="$(newest_present)"
    sleep 6
    p2="$(newest_present)"
    kill "$lpid" 2>/dev/null

    delta="$(grep -ao "1st audio frame (after seek) rendered:[^+]*" "$log" \
      | grep -o "delta: -\?[0-9]*" | head -1 | grep -o -- "-\?[0-9]*$")"
    sync_time="$(grep -ao "1st video frame to render @[0-9.]*s, sync time: [0-9.]*" "$log" \
      | head -1 | grep -o "sync time: [0-9.]*" | cut -d' ' -f3)"
    pos="$(grep -o "pos=[0-9]*" "$log" | tail -2 | tr '\n' ' ')"
    # Milliseconds of new presentation in a 6s window: ~6000 = playing.
    grew=$(( ( ${p2:-0} - ${p1:-0} ) / 1000000 ))
    verdict=FROZEN
    (( grew > 1000 )) && verdict=OK
    printf '%-11s run%-2s delta=%-12s sync=%-12s presentedMs/6s=%-6s pos=%-14s %s\n' \
      "$b" "$run" "${delta:-?}" "${sync_time:-?}" "$grew" "${pos:-?}" "$verdict" \
      | tee -a "$summary"
  done
done

adb -s "$SERIAL" shell am force-stop "$PKG" >/dev/null 2>&1
echo
echo "logs + summary in $OUTDIR"
cat "$summary"
