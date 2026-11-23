#!/usr/bin/env bash
# Records a Kiosk Twins run into an intermediate MP4.
#
# Windows (primary target):
#   - Launch the demo:
#       flutter run -d windows --dart-define=STORE=file
#     (Once Phase F lands, add --dart-define=DEMO_MODE=true and the
#     scripted beats play themselves; until then, drive the buttons
#     manually while recording.)
#   - Wait for the window titled "Kiosk Twins", then run this script.
#
# The capture uses ffmpeg's gdigrab against the window title. Adjust
# DURATION to the demo run time (the script budgets 45-60 s).
set -euo pipefail

DURATION=${DURATION:-60}
OUT=${OUT:-demo_capture.mp4}

echo "Recording Kiosk Twins window for ${DURATION}s -> ${OUT}"
ffmpeg -y \
  -f gdigrab -framerate 15 \
  -i title="Kiosk Twins" \
  -t "$DURATION" \
  -c:v libx264 -preset veryfast -crf 20 \
  "$OUT"
echo "done: $OUT"
