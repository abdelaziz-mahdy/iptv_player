#!/usr/bin/env bash
# Pulls the app's persistent log files off the TV (survives logcat rotation
# and app restarts; written by lib/core/logging/app_logger.dart).
#
# Usage: scripts/pull_logs.sh [output-dir]     (default tv-logs/<date-time>)
# Env:   SERIAL adb device (default 192.168.2.17:5555)
set -euo pipefail

S="${SERIAL:-192.168.2.17:5555}"
OUT="${1:-tv-logs/$(date +%F-%H%M)}"

adb connect "$S" >/dev/null 2>&1 || true
mkdir -p "$OUT"
adb -s "$S" pull /sdcard/Android/data/com.iptvplayer/files/logs "$OUT" >/dev/null
echo "logs -> $OUT/logs/"
ls -lh "$OUT/logs/"
