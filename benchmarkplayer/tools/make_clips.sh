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

echo
echo "Clips in $DIR:"
ls -lh "$DIR"/*.mp4
