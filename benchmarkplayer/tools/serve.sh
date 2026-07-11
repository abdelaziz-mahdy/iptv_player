#!/usr/bin/env bash
# Serves the reference clips over the LAN so the TV pulls byte-identical
# content with ~0 network jitter (removes the IPTV provider as a variable).
#
# Usage: tools/serve.sh [port]   (default 8000)
set -euo pipefail

PORT="${1:-8000}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/media"

if ! ls "$DIR"/*.mp4 >/dev/null 2>&1; then
  echo "No clips in $DIR — run tools/make_clips.sh first." >&2
  exit 1
fi

IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo 127.0.0.1)"
echo "Serving $DIR on http://$IP:$PORT/"
for f in "$DIR"/*.mp4; do
  echo "  http://$IP:$PORT/$(basename "$f")"
done
echo
cd "$DIR"
exec python3 -m http.server "$PORT"
