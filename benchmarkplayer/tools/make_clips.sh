#!/usr/bin/env bash
# Generates the reference clips used by the pacing benchmark into media/.
# testsrc2 burns a timecode + frame counter into the frame (top-left) and is
# motion-rich; the sine audio beeps every second (A/V sync check by ear).
#
# Usage: tools/make_clips.sh [duration-seconds]   (default 360)
set -euo pipefail

DUR="${1:-360}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/media"
mkdir -p "$DIR"

encode() { # $1=fps $2=outfile $3=extra-input-args(audio or empty)
  local fps="$1" out="$2" audio="$3"
  if [[ -f "$DIR/$out" ]]; then
    echo "skip $out (exists)"
    return
  fi
  echo "encoding $out (${fps}fps, ${DUR}s)"
  if [[ -n "$audio" ]]; then
    ffmpeg -y -v error \
      -f lavfi -i "testsrc2=size=1920x1080:rate=$fps" \
      -f lavfi -i "sine=frequency=440:beep_factor=4" \
      -t "$DUR" \
      -c:v libx264 -preset veryfast -profile:v high -level 4.1 \
      -b:v 6M -maxrate 6M -bufsize 12M -pix_fmt yuv420p \
      -g "$((fps * 2))" \
      -c:a aac -b:a 128k -ar 48000 \
      -movflags +faststart \
      "$DIR/$out"
  else
    ffmpeg -y -v error \
      -f lavfi -i "testsrc2=size=1920x1080:rate=$fps" \
      -t "$DUR" \
      -c:v libx264 -preset veryfast -profile:v high -level 4.1 \
      -b:v 6M -maxrate 6M -bufsize 12M -pix_fmt yuv420p \
      -g "$((fps * 2))" -an \
      -movflags +faststart \
      "$DIR/$out"
  fi
}

encode 24 bench-24fps.mp4 audio
encode 25 bench-25fps.mp4 audio
encode 50 bench-50fps.mp4 audio
encode 24 bench-24fps-noaudio.mp4 ""

# High-load clips for the render-path limit test (texture vs platform view vs
# direct decoder output). 4K/60fps encodes are slow, so they're short — the
# bench app loops the clip. h264 for 1080p60 + a 4K24 codec pair (h264 may hit
# decoder level limits at 4K on TV chips; hevc is the native 4K codec there).
DUR_HEAVY="${DUR_HEAVY:-120}"

encode_heavy() { # $1=size $2=fps $3=vcodec+opts $4=outfile
  local size="$1" fps="$2" out="$4"
  if [[ -f "$DIR/$out" ]]; then
    echo "skip $out (exists)"
    return
  fi
  echo "encoding $out (${size}@${fps}fps, ${DUR_HEAVY}s)"
  # shellcheck disable=SC2086  # $3 is a codec + options word list
  ffmpeg -y -v error \
    -f lavfi -i "testsrc2=size=$size:rate=$fps" \
    -f lavfi -i "sine=frequency=440:beep_factor=4" \
    -t "$DUR_HEAVY" \
    -pix_fmt yuv420p $3 -g "$((fps * 2))" \
    -c:a aac -b:a 128k -ar 48000 \
    -movflags +faststart \
    "$DIR/$out"
}

encode_heavy 1920x1080 60 "-c:v libx264 -preset veryfast -profile:v high -level 4.2 -b:v 10M -maxrate 10M -bufsize 20M" bench-1080p60.mp4
encode_heavy 3840x2160 24 "-c:v libx264 -preset veryfast -profile:v high -level 5.1 -b:v 25M -maxrate 25M -bufsize 50M" bench-4k24-h264.mp4
encode_heavy 3840x2160 24 "-c:v libx265 -preset veryfast -tag:v hvc1 -b:v 20M -maxrate 20M -bufsize 40M" bench-4k24-hevc.mp4
encode_heavy 3840x2160 60 "-c:v libx265 -preset veryfast -tag:v hvc1 -b:v 30M -maxrate 30M -bufsize 60M" bench-4k60-hevc.mp4
# HDR pair for the direct-surface wedge repro (mdk-sdk#361): hevc 10-bit HDR10
# plays; h264 8-bit with the same PQ/BT2020 VUI signaling wedges the decoder.
encode_heavy 3840x2160 24 "-c:v libx265 -preset veryfast -tag:v hvc1 -pix_fmt yuv420p10le -b:v 20M -maxrate 20M -bufsize 40M -x265-params colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400:hdr10=1:hdr10-opt=1" bench-4k24-hdr10.mp4
encode_heavy 3840x1600 24 "-c:v libx264 -preset veryfast -profile:v high -level 5.1 -b:v 15M -maxrate 15M -bufsize 30M -x264-params colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc" bench-4k24-h264hdr.mp4

echo
echo "Clips in $DIR:"
ls -lh "$DIR"/*.mp4
