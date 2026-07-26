#!/usr/bin/env bash
# Simulates a live stream locally: loops a reference clip into a rolling HLS
# playlist (old segments deleted, no ENDLIST -> players treat it as live).
# Serve with tools/serve.sh alongside the VOD clips; leave this running for
# the *-live bench variants. Tests live semantics (no duration, growing
# playlist, realtime delivery) without the IPTV provider as a variable.
#
# TS_OFFSET (seconds, default 7760) starts the stream's timestamps far from
# zero, the way a provider's live TS does. That is what exposes the MDK audio
# clock bug: when the clock starts at 0 instead of the stream's own base, video
# frames are hours "in the future" and none is ever presented — frozen picture,
# audio fine. Set TS_OFFSET=0 for a plain zero-based live stream.
#
# Usage: tools/make_live.sh   (Ctrl-C to stop)
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)/media"
LIVE="$DIR/live"

if [[ ! -f "$DIR/bench-24fps.mp4" ]]; then
  echo "No clips — run tools/make_clips.sh first." >&2
  exit 1
fi

TS_OFFSET="${TS_OFFSET:-7760}"

rm -rf "$LIVE"
mkdir -p "$LIVE"
echo "live playlist: http://<mac-ip>:8000/live/stream.m3u8 (ts offset ${TS_OFFSET}s)"
exec ffmpeg -v warning -re -stream_loop -1 -i "$DIR/bench-24fps.mp4" -c copy \
  -output_ts_offset "$TS_OFFSET" \
  -f hls -hls_time 4 -hls_list_size 6 \
  -hls_flags delete_segments+append_list+omit_endlist \
  -hls_segment_filename "$LIVE/seg%05d.ts" "$LIVE/stream.m3u8"
