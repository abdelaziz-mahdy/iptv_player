#!/usr/bin/env bash
# Run the 3-way render comparison on the TV, then restore the committed
# manifest. Usage: scripts/tv_render_all.sh <serial>
set -uo pipefail
S="${1:?serial}"
for mode in vulkan opengles skia; do
  echo; echo "############### $mode ###############"
  bash scripts/tv_render_test.sh "$S" "$mode" 9 || echo "[$mode] failed"
done
echo; echo "== restoring committed manifest =="
git checkout -- android/app/src/main/AndroidManifest.xml && echo "manifest restored"
echo "videos: /tmp/render_vulkan.mp4  /tmp/render_opengles.mp4  /tmp/render_skia.mp4"
