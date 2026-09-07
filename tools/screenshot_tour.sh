#!/usr/bin/env bash
# Render README screenshots from the real app against demo data.
#
# The app's posters come from the network, so the tour needs the generated
# demo artwork served over HTTP — cached_network_image has its own HTTP stack
# and ignores a Dart HttpOverrides, so a real local server is the reliable way
# to get artwork into the frame.
#
#   tools/screenshot_tour.sh [outdir]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-docs/screenshots}"
ART="${DEMO_ART_DIR:?set DEMO_ART_DIR to the generated artwork directory}"
PORT="${DEMO_ART_PORT:-8099}"

[ -d "$ART" ] || { echo "no artwork at $ART — run the generator first" >&2; exit 1; }

python3 -m http.server "$PORT" --directory "$ART" --bind 127.0.0.1 >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
sleep 1
curl -sf "http://127.0.0.1:$PORT/movie0.png" -o /dev/null || {
  echo "artwork server did not come up on $PORT" >&2; exit 1; }

echo ">> tour -> $OUT"
flutter test integration_test/screenshots_test.dart -d macos \
  --dart-define=SHOT_DIR="$OUT" \
  --dart-define=DEMO_ART="http://127.0.0.1:$PORT" 2>&1 | grep -E "\[SHOT\]|overflowed|Error|error •|All tests|Some tests" || true

# The tour renders at 2x for sharpness; committing 7.5 MB of PNGs to show six
# screens is not worth it, and a 1500 px JPEG is indistinguishable in a README.
echo ">> compressing"
find "$OUT" -name '*.png' | while read -r f; do
  sips -Z 1500 "$f" --out /tmp/_shot.png >/dev/null 2>&1 || continue
  sips -s format jpeg -s formatOptions 78 /tmp/_shot.png --out "${f%.png}.jpg" >/dev/null 2>&1 \
    && rm -f "$f"
done
rm -f /tmp/_shot.png

echo
find "$OUT" -name '*.jpg' | sort
du -sh "$OUT" 2>/dev/null
