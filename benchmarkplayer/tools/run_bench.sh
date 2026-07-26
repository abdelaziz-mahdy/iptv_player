#!/usr/bin/env bash
# Frame-pacing benchmark orchestrator, fully unattended: builds one APK per
# variant, installs it on the TV, launches it, verifies playback from the
# app's own stats lines, captures logcat + SurfaceFlinger present timestamps,
# force-stops, and writes a per-variant results folder ready for
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
#   DURATION sampling seconds      (default 60)
#   OUTDIR   results dir           (default bench-results/<yyyy-mm-dd>)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERIAL="${SERIAL:-192.168.2.17:5555}"
DURATION="${DURATION:-60}"
# Seek target for the resume-repro variants (clip is 360s).
RESUME_AT="${RESUME_AT:-300}"
# Runs per variant — the resume bug is intermittent (~3 in 5 on the TV).
REPEAT="${REPEAT:-1}"
OUTDIR="${OUTDIR:-$ROOT/bench-results/$(date +%F)}"
APKDIR="$ROOT/bench-results/apks"
PKG=com.iptvplayer.benchmark_player

if [[ -z "${URLBASE:-}" ]]; then
  IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
  URLBASE="http://$IP:8000"
fi

CLIP="$URLBASE/bench-24fps.mp4"
CLIP_NOAUDIO="$URLBASE/bench-24fps-noaudio.mp4"
CLIP_1080P60="$URLBASE/bench-1080p60.mp4"
CLIP_4K24="$URLBASE/bench-4k24-hevc.mp4"
CLIP_4K24_H264="$URLBASE/bench-4k24-h264.mp4"
CLIP_4K60="$URLBASE/bench-4k60-hevc.mp4"
# Local simulated live stream (tools/make_live.sh); export LIVE_URL to use a
# real provider channel instead (credentials get baked into that apk — keep it local).
LIVE="${LIVE_URL:-$URLBASE/live/stream.m3u8}"

# variant -> dart-defines (BENCH_VARIANT and BENCH_URL are filled in below)
variant_defines() {
  case "$1" in
    01-media_kit-baseline) echo "BENCH_BACKEND=media_kit BENCH_URL=$CLIP" ;;
    02-fvp-default)        echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP" ;;
    03-fvp-copy)           echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_DECODER_COPY=true" ;;
    04-fvp-audiotrack)     echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_AUDIO_BACKEND=AudioTrack" ;;
    05-fvp-noaudio)        echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP_NOAUDIO" ;;
    06-media_kit-live)     echo "BENCH_BACKEND=media_kit BENCH_URL=$LIVE" ;;
    07-fvp-live)           echo "BENCH_BACKEND=fvp BENCH_URL=$LIVE" ;;
    08-media_kit-noaudio)  echo "BENCH_BACKEND=media_kit BENCH_URL=$CLIP_NOAUDIO" ;;
    09-fvp-opensl)         echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_AUDIO_BACKEND=OpenSL" ;;
    10-fvp-live-opensl)    echo "BENCH_BACKEND=fvp BENCH_URL=$LIVE FVP_AUDIO_BACKEND=OpenSL" ;;
    11-media_kit-aaudio)   echo "BENCH_BACKEND=media_kit BENCH_URL=$CLIP BENCH_MPV_AO=aaudio" ;;
    # -- render-path matrix (fvp PR #379 discussion): texture (old view) vs
    # platform view + GL (new view) vs platform view + MediaCodec-to-surface
    # (wang-bin's suggestion). All fvp runs pin OpenSL so the audio clock is
    # never the variable. pvd-* additionally launches with the direct_surface
    # extra (see variant_extras) — the dart-defines are the pv ones.
    [234][0-9]-fvp-tex-*)   echo "BENCH_BACKEND=fvp BENCH_URL=$(clip_for "$1") FVP_AUDIO_BACKEND=OpenSL" ;;
    [234][0-9]-fvp-pvd-*|[234][0-9]-fvp-pv-*)
                           echo "BENCH_BACKEND=fvp BENCH_URL=$(clip_for "$1") BENCH_VIEW=platform FVP_AUDIO_BACKEND=OpenSL" ;;
    3[0-9]-media_kit-*)    echo "BENCH_BACKEND=media_kit BENCH_URL=$(clip_for "$1")" ;;
    # -- resume repro (mdk-sdk): open, then seek to RESUME_AT before play.
    # MDK sometimes starts the audio clock at 0 instead of the seek position;
    # video is paced against it, so frames never come due — frozen picture,
    # audio fine. Texture view, so the platform-view work is not involved.
    7[0-9]-resume-opensl)     echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_AUDIO_BACKEND=OpenSL BENCH_SEEK=$RESUME_AT" ;;
    7[0-9]-resume-aaudio)     echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_AUDIO_BACKEND=AAudio BENCH_SEEK=$RESUME_AT" ;;
    7[0-9]-resume-audiotrack) echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP FVP_AUDIO_BACKEND=AudioTrack BENCH_SEEK=$RESUME_AT" ;;
    7[0-9]-resume-default)    echo "BENCH_BACKEND=fvp BENCH_URL=$CLIP BENCH_SEEK=$RESUME_AT" ;;
    *) return 1 ;;
  esac
}

# Clip for a matrix variant, from its trailing -<clip> token.
clip_for() {
  case "${1##*-}" in
    1080p24) echo "$CLIP" ;;
    1080p60) echo "$CLIP_1080P60" ;;
    4k24)    echo "$CLIP_4K24" ;;
    4k24hdr) echo "$URLBASE/bench-4k24-hdr10.mp4" ;;
    h264hdr) echo "$URLBASE/bench-4k24-h264hdr.mp4" ;;
    4k24h264) echo "$CLIP_4K24_H264" ;;
    4k60)    echo "$CLIP_4K60" ;;
    *) echo "$CLIP" ;;
  esac
}

# Extra `am start` args per variant (runtime switches that don't need a rebuild).
variant_extras() {
  case "$1" in
    # HDR repro variants must FORCE direct mode — the fork otherwise routes
    # HDR content back to the GL path (mdk-sdk#361 escape hatch).
    4[01]-fvp-pvd-*) echo "--es direct_mode force" ;;
    *-pvd-*) echo "--ez direct_surface true" ;;
    *) echo "" ;;
  esac
}

ALL_VARIANTS=(01-media_kit-baseline 02-fvp-default 03-fvp-copy 04-fvp-audiotrack
              05-fvp-noaudio 06-media_kit-live 07-fvp-live)
EXTRA_VARIANTS=(08-media_kit-noaudio 09-fvp-opensl 10-fvp-live-opensl)
# Resume repro across audio backends; run with REPEAT=5.
RESUME_VARIANTS=(70-resume-opensl 71-resume-aaudio 72-resume-audiotrack
                 73-resume-default)
# The render-path × load matrix. mpv references show the device ceiling per
# clip (mpv 1080p24 = variant 01).
MATRIX_VARIANTS=(20-fvp-tex-1080p24 21-fvp-pv-1080p24 22-fvp-pvd-1080p24
                 23-fvp-tex-1080p60 24-fvp-pv-1080p60 25-fvp-pvd-1080p60
                 26-fvp-tex-4k24    27-fvp-pv-4k24    28-fvp-pvd-4k24
                 29-fvp-tex-4k60    30-fvp-pv-4k60    31-fvp-pvd-4k60
                 32-media_kit-1080p60 33-media_kit-4k24 34-media_kit-4k60)

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
  # `|| true` everywhere: a no-match grep exits 1 and a bare var=$(pipeline)
  # would abort the whole script under set -e/pipefail.
  local layers candidates
  layers="$(adb -s "$SERIAL" shell dumpsys SurfaceFlinger --list 2>/dev/null \
    | tr -d '\r' | grep "$PKG" | grep -v "^Background for" || true)"
  # Frames land on the SurfaceView's (BLAST) child; the bare
  # "SurfaceView[...]#0" container and "Background for SurfaceView[...]"
  # layers never receive buffers and dump empty latency data.
  candidates="$(printf '%s\n' "$layers" | grep -i "surfaceview" | grep "(BLAST)" || true)"
  if [[ -z "$candidates" ]]; then
    candidates="$(printf '%s\n' "$layers" | grep -i "surfaceview" || true)"
  fi
  if [[ -z "$candidates" ]]; then
    candidates="$(printf '%s\n' "$layers" | grep "(BLAST)" || true)"
  fi
  local n
  n="$(printf '%s\n' "$candidates" | grep -c . || true)"
  if (( n <= 1 )); then
    printf '%s\n' "$candidates" | head -1
    return
  fi
  # Platform-view runs have TWO SurfaceViews for the package (Flutter's own
  # output + FvpVideoView) with indistinguishable names. Pick the one whose
  # present timestamps advance: sample each twice, 2s apart, and keep the
  # layer with the most new frames (video pushes ~24-60/s; a static UI ~0).
  # `</dev/null` on the adb calls: adb otherwise slurps the loop's stdin
  # (the remaining candidate lines), so only the first layer ever got probed.
  local best="" best_count=-1 layer a count
  while IFS= read -r layer; do
    [[ -z "$layer" ]] && continue
    a="$(adb -s "$SERIAL" shell dumpsys SurfaceFlinger --latency "\"$layer\"" </dev/null \
      | tr -d '\r' | awk 'NF==3 && $2!=0 && $2!~/922337203685477/ {t=$2} END{print t+0}' || true)"
    sleep 2
    count="$(adb -s "$SERIAL" shell dumpsys SurfaceFlinger --latency "\"$layer\"" </dev/null \
      | tr -d '\r' \
      | awk -v last="${a:-0}" 'NF==3 && $2!=0 && $2!~/922337203685477/ && $2+0 > last+0 {c++} END{print c+0}' \
      || true)"
    echo "   layer probe: ${count:-0} new frames on: $layer" >&2
    if (( ${count:-0} > best_count )); then
      best_count="${count:-0}"
      best="$layer"
    fi
  done <<< "$candidates"
  printf '%s\n' "$best"
}

run_variant() {
  local v="$1" vdir="$OUTDIR/$v" extras
  extras="$(variant_extras "$v")"
  build_variant "$v"
  mkdir -p "$vdir"

  echo "== $v: installing on $SERIAL"
  adb -s "$SERIAL" install -r "$APKDIR/$v.apk" >/dev/null

  adb -s "$SERIAL" logcat -c || true
  adb -s "$SERIAL" logcat -v time > "$vdir/logcat.txt" &
  local logcat_pid=$!

  # The Google TV ambient screensaver reclaims the screen after idle periods
  # with no remote input — the activity then loses its surface and the run
  # silently measures the screensaver. Wake the panel and dismiss any active
  # ambient session before launching (FLAG_KEEP_SCREEN_ON in the app keeps it
  # away once the bench is in front).
  adb -s "$SERIAL" shell input keyevent KEYCODE_WAKEUP || true
  sleep 2

  echo "== $v: launching${extras:+ ($extras)}"
  # shellcheck disable=SC2086  # extras is a word list of am-start args
  adb -s "$SERIAL" shell am start -n "$PKG/.MainActivity" $extras >/dev/null

  # Wait for playback instead of a blind sleep: two stats lines (5s apart)
  # are enough to judge position advance. Cap at 30s for crashed launches.
  echo "== $v: waiting for playback (max 30s)"
  local waited=0
  while (( waited < 30 )); do
    if (( $(grep -c "BENCH_STATS. variant=$v .*pos=" "$vdir/logcat.txt" 2>/dev/null || echo 0) >= 2 )); then
      break
    fi
    sleep 2
    waited=$((waited + 2))
  done
  local pos_lines
  # Match this variant's label so leftovers from a previous run (if logcat -c
  # failed) can't fake a "playing" signal.
  pos_lines="$(grep -o "BENCH_STATS. variant=$v .*pos=[0-9]*" "$vdir/logcat.txt" \
    | grep -o 'pos=[0-9]*' | tail -2 | tr '\n' ' ' || true)"
  if [[ -z "$pos_lines" ]]; then
    echo "!! $v: no BENCH_STATS in logcat — app not running or crashed" >&2
    tail -5 "$vdir/logcat.txt" >&2 || true
    kill "$logcat_pid" 2>/dev/null || true
    exit 1
  fi
  set -- $pos_lines
  if [[ $# -ge 2 && "${1:-}" == "${2:-x}" ]]; then
    echo "!! $v: position not advancing ($pos_lines) — playback stalled?" >&2
    echo "   continuing anyway; check $vdir/stats.txt afterwards" >&2
  fi
  echo "== $v: playing ($pos_lines)"

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
  : > "$vdir/cpu.txt"
  local end=$((SECONDS + DURATION)) tick=0
  while (( SECONDS < end )); do
    echo "=== $(date +%s)" >> "$vdir/pacing_raw.txt"
    adb -s "$SERIAL" shell dumpsys SurfaceFlinger --latency "\"$layer\"" \
      | tr -d '\r' >> "$vdir/pacing_raw.txt" || true
    # CPU load snapshot every ~5s: our process + total, for the render-path
    # comparison (GL composition vs direct decoder output).
    if (( tick % 5 == 0 )); then
      {
        echo "=== $(date +%s)"
        adb -s "$SERIAL" shell top -b -n 1 2>/dev/null | LC_ALL=C tr -d '\r' \
          | grep -E "benchmark_player|surfaceflinger|^ *[0-9]+%|[0-9]+%cpu" | head -8
      } >> "$vdir/cpu.txt" || true
    fi
    tick=$((tick + 1))
    sleep 1
  done

  adb -s "$SERIAL" shell am force-stop "$PKG" || true
  kill "$logcat_pid" 2>/dev/null || true
  wait "$logcat_pid" 2>/dev/null || true

  # Split the capture into focused files.
  grep -E "\[mpv\]|\[mdk\]" "$vdir/logcat.txt" > "$vdir/player.log" || true
  grep -E "BENCH_META|BENCH_STATS|BENCH_ERROR" "$vdir/logcat.txt" > "$vdir/stats.txt" || true
  grep "EGL_PROBE" "$vdir/logcat.txt" > "$vdir/egl_probe.txt" || true

  {
    echo "variant   : $v"
    echo "defines   : $(variant_defines "$v") BENCH_VARIANT=$v"
    echo "extras    : ${extras:-none}"
    echo "date      : $(date -u +%FT%TZ)"
    echo "duration  : ${DURATION}s"
    echo "device    : $(adb -s "$SERIAL" shell getprop ro.product.model | tr -d '\r')"
    echo "android   : $(adb -s "$SERIAL" shell getprop ro.build.version.release | tr -d '\r')"
    echo "layer     : $layer"
  } > "$vdir/meta.txt"

  # A variant with unusable pacing data shouldn't end the whole batch — the
  # failure is recorded in histogram.txt and visible in comparison.md.
  if ! python3 "$ROOT/tools/analyze_pacing.py" "$vdir/pacing_raw.txt" \
    | tee "$vdir/histogram.txt"; then
    echo "!! $v: pacing analysis failed (see $vdir)" >&2
  fi
  echo
  echo "== $v: done -> $vdir"
  echo
}

cmd="${1:-run}"
shift || true

case "$cmd" in
  list)
    printf '%s\n' "${ALL_VARIANTS[@]}" && printf '(extra) %s\n' "${EXTRA_VARIANTS[@]}" \
      && printf '(matrix) %s\n' "${MATRIX_VARIANTS[@]}"
    ;;
  build)
    variants=("$@")
    [[ ${#variants[@]} -eq 0 ]] && variants=("${ALL_VARIANTS[@]}")
    for v in "${variants[@]}"; do build_variant "$v"; done
    ;;
  run)
    variants=("$@")
    [[ ${#variants[@]} -eq 0 ]] && variants=("${ALL_VARIANTS[@]}")
    echo "device: $SERIAL   clips: $URLBASE   sample: ${DURATION}s/variant"
    echo "variants: ${variants[*]}"
    echo "(tools/serve.sh must be running; tools/make_live.sh too for *-live variants)"
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
