#!/usr/bin/env bash
# Regenerate the documentation media (screenshots + optional walkthrough video).
#
#   tools/gen_docs.sh                 # screenshots only
#   tools/gen_docs.sh --video         # also record the walkthrough
#   tools/gen_docs.sh --device emulator-5554
#
# Requires: a running Android device/emulator, `flutter` and `adb` on PATH. The app is
# driven in DEV MODE so every screen is populated with simulated data (no pump needed).
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE=""
VIDEO=0
VIDEO_SECONDS=120
while [[ $# -gt 0 ]]; do
  case "$1" in
    --video) VIDEO=1; shift;;
    --device) DEVICE="$2"; shift 2;;
    --seconds) VIDEO_SECONDS="$2"; shift 2;;
    *) echo "unknown arg: $1"; exit 1;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  DEVICE=$(flutter devices 2>/dev/null | grep -Eo '(emulator-[0-9]+)' | head -n1 || true)
  [[ -z "$DEVICE" ]] && { echo "No Android device found. Start an emulator or pass --device."; exit 1; }
fi
echo "Using device: $DEVICE"

echo "Capturing screenshots -> doc/screenshots/ ..."
flutter drive \
  --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/screenshots_test.dart \
  -d "$DEVICE"
echo "Screenshots done."

if [[ "$VIDEO" == "1" ]]; then
  mkdir -p doc/media
  echo "Recording walkthrough (~${VIDEO_SECONDS}s) ..."
  adb -s "$DEVICE" shell screenrecord --time-limit "$VIDEO_SECONDS" --bit-rate 6000000 /sdcard/bgdude_walkthrough.mp4 &
  REC_PID=$!
  sleep 2
  flutter test integration_test/walkthrough_test.dart -d "$DEVICE" || true
  adb -s "$DEVICE" shell 'pkill -INT screenrecord' || true
  sleep 3
  wait "$REC_PID" 2>/dev/null || true
  adb -s "$DEVICE" pull /sdcard/bgdude_walkthrough.mp4 doc/media/walkthrough.mp4
  echo "Walkthrough video -> doc/media/walkthrough.mp4"
  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y -i doc/media/walkthrough.mp4 -vf "fps=10,scale=360:-1:flags=lanczos" doc/media/walkthrough.gif
    echo "Walkthrough GIF -> doc/media/walkthrough.gif"
  else
    echo "(ffmpeg not found — skipped GIF; the mp4 embeds fine in the docs.)"
  fi
fi

echo "Open doc/index.html to view the docs."
