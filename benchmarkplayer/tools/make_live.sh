#!/usr/bin/env bash
# Simulates a live stream locally: loops a reference clip into a rolling HLS
# playlist (old segments deleted, no ENDLIST -> players treat it as live).
# Serve with tools/serve.sh alongside the VOD clips; leave this running for
# the *-live bench variants. Tests live semantics (no duration, growing
# playlist, realtime delivery) without the IPTV provider as a variable.
#
# Usage: tools/make_live.sh   (Ctrl-C to stop)
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)/media"
LIVE="$DIR/live"

if [[ ! -f "$DIR/bench-24fps.mp4" ]]; then
  echo "No clips — run tools/make_clips.sh first." >&2
  exit 1
fi

rm -rf "$LIVE"
mkdir -p "$LIVE"
echo "live playlist: http://<mac-ip>:8000/live/stream.m3u8"
exec ffmpeg -v warning -re -stream_loop -1 -i "$DIR/bench-24fps.mp4" -c copy \
  -f hls -hls_time 4 -hls_list_size 6 \
  -hls_flags delete_segments+append_list+omit_endlist \
  -hls_segment_filename "$LIVE/seg%05d.ts" "$LIVE/stream.m3u8"
