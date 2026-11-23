#!/usr/bin/env bash
# Converts the captured MP4 into the animated GIF that ships in the
# cell_memory README: two-pass palette, 960 px wide, ~12 fps.
#
#   ./make_gif.sh demo_capture.mp4 ../../
#
# The GIF lands next to this script; copy it to
# packages/cell_memory/doc/live-demo.gif (plus doc/live-demo.png as the
# static fallback: `ffmpeg -i demo_capture.mp4 -frames:v 1 ...`).
set -euo pipefail

SRC=${1:-demo_capture.mp4}
WIDTH=${WIDTH:-960}
FPS=${FPS:-12}
OUT=${OUT:-live-demo.gif}

echo "palette + gif: $SRC -> $OUT"
ffmpeg -y -i "$SRC" -vf "fps=${FPS},scale=${WIDTH}:-1:flags=lanczos,palettegen" palette.png
ffmpeg -y -i "$SRC" -i palette.png -lavfi "fps=${FPS},scale=${WIDTH}:-1:flags=lanczos [x]; [x][1:v] paletteuse" "$OUT"
rm -f palette.png
echo "done: $OUT ($(du -h "$OUT" | cut -f1))"
