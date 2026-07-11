#!/usr/bin/env bash
# Frame-pacing benchmark orchestrator: builds one APK per variant, installs
# it on the TV, captures logcat + SurfaceFlinger present timestamps while you
# watch the clip, and writes a per-variant results folder ready for
# comparison / an upstream ticket.
#
# Usage:
#   tools/run_bench.sh build                 # just build all variant APKs
#   tools/run_bench.sh run [variant ...]     # full measurement (default: all)
#   tools/run_bench.sh list                  # show the variant matrix
#
# Env overrides:
#   SERIAL   adb device            (default 192.168.2.17:5555)
#   URLBASE  clip server base URL  (default http://<mac-ip>:8000)
#   DURATION sampling seconds      (default 300)
#   OUTDIR   results dir           (default bench-results/<yyyy-mm-dd>)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERIAL="${SERIAL:-192.168.2.17:5555}"
DURATION="${DURATION:-300}"
OUTDIR="${OUTDIR:-$ROOT/bench-results/$(date +%F)}"
APKDIR="$ROOT/bench-results/apks"
PKG=com.iptvplayer.benchmark_player

if [[ -z "${URLBASE:-}" ]]; then
  IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
  URLBASE="http://$IP:8000"
fi

CLIP="$URLBASE/bench-24fps.mp4"
CLIP_NOAUDIO="$URLBASE/bench-24fps-noaudio.mp4"

# variant -> dart-defines (BENCH_VARIANT and BENCH_URL are filled in below)
variant_defines() {
  case "$1" in
    01-media_kit-baseline) echo "BENCH_BACKEND=media_kit BENCH_URL=$CLIP" ;;
    02-fvp-default)        echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP" ;;
    03-fvp-copy)           echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_DECODER_COPY=true" ;;
    04-fvp-audiotrack)     echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_AUDIO_BACKEND=AudioTrack" ;;
    05-fvp-noaudio)        echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP_NOAUDIO" ;;
    06-media_kit-noaudio)  echo "BENCH_BACKEND=media_kit BENCH_URL=$CLIP_NOAUDIO" ;;
    07-fvp-opensl)         echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_AUDIO_BACKEND=OpenSL" ;;
    *) return 1 ;;
  esac
}

ALL_VARIANTS=(01-media_kit-baseline 02-fvp-default 03-fvp-copy 04-fvp-audiotrack 05-fvp-noaudio)
EXTRA_VARIANTS=(06-media_kit-noaudio 07-fvp-opensl)

build_variant() {
  local v="$1" defines flags=()
  defines="$(variant_defines "$v")" || { echo "unknown variant: $v" >&2; exit 2; }
  mkdir -p "$APKDIR"
  # BENCH_URL is baked in at build time — reuse the cached apk only if it
  # was built against the same URLBASE (the Mac's LAN IP can change).
  if [[ -f "$APKDIR/$v.apk" && "$(cat "$APKDIR/$v.url" 2>/dev/null)" == "$URLBASE" ]]; then
    echo "== $v: apk cached for $URLBASE, skipping build"
    return
  fi
  for d in $defines "BENCH_VARIANT=$v"; do flags+=(--dart-define="$d"); done
  echo "== $v: flutter build apk --release ${flags[*]}"
  (cd "$ROOT" && flutter build apk --release "${flags[@]}" >/dev/null)
  cp "$ROOT/build/app/outputs/flutter-apk/app-release.apk" "$APKDIR/$v.apk"
  echo "$URLBASE" > "$APKDIR/$v.url"
  echo "== $v: built -> $APKDIR/$v.apk"
}

detect_layer() {
  # Prefer a SurfaceView layer for our package; fall back to the app window.
  local layer
  layer="$(adb -s "$SERIAL" shell dumpsys SurfaceFlinger --list 2>/dev/null \
    | tr -d '\r' | grep "$PKG" | grep -i "surfaceview" | head -1)"
  if [[ -z "$layer" ]]; then
    layer="$(adb -s "$SERIAL" shell dumpsys SurfaceFlinger --list 2>/dev/null \
      | tr -d '\r' | grep "$PKG" | grep "(BLAST)" | head -1)"
  fi
  echo "$layer"
}

run_variant() {
  local v="$1" vdir="$OUTDIR/$v"
  build_variant "$v"
  mkdir -p "$vdir"

  echo "== $v: installing on $SERIAL"
  adb -s "$SERIAL" install -r "$APKDIR/$v.apk" >/dev/null
  echo
  echo ">>> On the TV: open 'FVP Bench'. It autoplays the clip."
  read -r -p ">>> Press Enter here once the video is PLAYING... "

  adb -s "$SERIAL" logcat -c || true
  adb -s "$SERIAL" logcat -v time > "$vdir/logcat.txt" &
  local logcat_pid=$!

  # Let startup + the on-screen badge (hides at 15s) pass before measuring.
  echo "== $v: waiting 20s (startup + badge)"
  sleep 20

  local layer
  layer="$(detect_layer)"
  if [[ -z "$layer" ]]; then
    echo "!! no SurfaceFlinger layer found for $PKG — is the app in front?" >&2
    kill "$logcat_pid" 2>/dev/null || true
    exit 1
  fi
  echo "== $v: sampling layer for ${DURATION}s:"
  echo "     $layer"
  : > "$vdir/pacing_raw.txt"
  local end=$((SECONDS + DURATION))
  while (( SECONDS < end )); do
    echo "=== $(date +%s)" >> "$vdir/pacing_raw.txt"
    adb -s "$SERIAL" shell dumpsys SurfaceFlinger --latency "\"$layer\"" \
      | tr -d '\r' >> "$vdir/pacing_raw.txt" || true
    sleep 1
  done

  kill "$logcat_pid" 2>/dev/null || true
  wait "$logcat_pid" 2>/dev/null || true

  # Split the capture into focused files.
  grep -E "\[mpv\]|\[mdk\]" "$vdir/logcat.txt" > "$vdir/player.log" || true
  grep -E "BENCH_META|BENCH_STATS|BENCH_ERROR" "$vdir/logcat.txt" > "$vdir/stats.txt" || true

  {
    echo "variant   : $v"
    echo "defines   : $(variant_defines "$v") BENCH_VARIANT=$v"
    echo "date      : $(date -u +%FT%TZ)"
    echo "duration  : ${DURATION}s"
    echo "device    : $(adb -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
    echo "android   : $(adb -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r')"
    echo "layer     : $layer"
  } > "$vdir/meta.txt"

  python3 "$ROOT/tools/analyze_pacing.py" "$vdir/pacing_raw.txt" \
    | tee "$vdir/histogram.txt"
  echo
  echo "== $v: done -> $vdir"
  echo ">>> You can stop/close the app on the TV now."
  echo
}

cmd="${1:-run}"
shift || true

case "$cmd" in
  list)
    printf '%s\n' "${ALL_VARIANTS[@]}" && printf '(extra) %s\n' "${EXTRA_VARIANTS[@]}"
    ;;
  build)
    for v in "${ALL_VARIANTS[@]}"; do build_variant "$v"; done
    ;;
  run)
    variants=("$@")
    [[ ${#variants[@]} -eq 0 ]] && variants=("${ALL_VARIANTS[@]}")
    echo "device: $SERIAL   clips: $URLBASE   sample: ${DURATION}s/variant"
    echo "variants: ${variants[*]}"
    echo "(make sure tools/serve.sh is running)"
    echo
    for v in "${variants[@]}"; do run_variant "$v"; done
    python3 "$ROOT/tools/summarize.py" "$OUTDIR" > "$OUTDIR/comparison.md"
    echo "==> $OUTDIR/comparison.md"
    ;;
  *)
    grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -16
    exit 2
    ;;
esac
