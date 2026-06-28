#!/usr/bin/env bash
# Find Android devices/TVs on the network (mDNS) + already-connected ones,
# let you pick one, connect, and install an APK.
#
#   scripts/install_on_tv.sh [apk]
#     apk: a path to an .apk, OR one of: opengles | skia | release
#          (maps to build/app/outputs/flutter-apk/app-<name>.apk; default: opengles)
#
# Examples:
#   scripts/install_on_tv.sh            # install app-opengles.apk
#   scripts/install_on_tv.sh skia       # install app-skia.apk
#   scripts/install_on_tv.sh /tmp/x.apk
set -uo pipefail

APKDIR="build/app/outputs/flutter-apk"
sel="${1:-opengles}"
case "$sel" in
  opengles|skia) APK="$APKDIR/app-$sel.apk" ;;
  release)       APK="$APKDIR/app-release.apk" ;;
  *)             APK="$sel" ;;   # treat as a path
esac
if [ ! -f "$APK" ]; then
  echo "✗ APK not found: $APK"
  echo "  build one first, e.g.: flutter build apk --release"
  exit 1
fi
echo "APK: $APK ($(du -h "$APK" | cut -f1))"

echo "Discovering devices (mDNS + connected)…"
# Network adb endpoints advertised over mDNS (ip:port on the last field).
mapfile -t MDNS < <(adb mdns services 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+' | sort -u)
# Already-connected/authorized devices.
mapfile -t CONN < <(adb devices | awk 'NR>1 && NF>=2 {print $1" ["$2"]"}')

CANDS=()
for d in "${CONN[@]}"; do CANDS+=("$d"); done
for m in "${MDNS[@]}"; do
  # skip if already in connected list
  case " ${CONN[*]} " in *" $m "*) ;; *) CANDS+=("$m [mdns]") ;; esac
done

if [ "${#CANDS[@]}" -eq 0 ]; then
  echo "No devices found. Is the TV awake and on Wi-Fi with ADB debugging on?"
fi

echo
echo "Pick a device:"
i=1
for c in "${CANDS[@]}"; do echo "  $i) $c"; i=$((i+1)); done
echo "  m) enter IP manually (e.g. 192.168.2.17:5555)"
echo "  q) quit"
printf "> "
read -r choice

case "$choice" in
  q|Q) exit 0 ;;
  m|M) printf "IP[:port] > "; read -r target; [[ "$target" == *:* ]] || target="$target:5555" ;;
  ''|*[!0-9]*) echo "invalid choice"; exit 1 ;;
  *)
    idx=$((choice-1))
    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#CANDS[@]}" ] || { echo "out of range"; exit 1; }
    target="$(echo "${CANDS[$idx]}" | awk '{print $1}')"
    ;;
esac

# Connect if it's a network endpoint not already in `device` state.
if [[ "$target" == *:* ]]; then
  echo "Connecting to $target …"
  adb connect "$target" >/dev/null 2>&1
  sleep 1
fi

state="$(adb devices | awk -v t="$target" '$1==t{print $2}')"
if [ "$state" = "unauthorized" ]; then
  echo "⚠ $target is UNAUTHORIZED — approve the 'Allow debugging' prompt on the TV,"
  echo "  then re-run this script."
  exit 1
fi
if [ "$state" != "device" ]; then
  echo "✗ could not reach $target (state: ${state:-none}). Is the TV awake / ADB enabled?"
  exit 1
fi

echo "Installing on $target …"
adb -s "$target" install -r "$APK"
echo "✓ installed. Launch it from the TV's app list (or it may appear on the leanback home)."
