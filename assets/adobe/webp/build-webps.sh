#!/usr/bin/env bash
#
# build-webps.sh — generate 320, 640, 1280-wide WebP animations

# target widths
WIDTHS=(320 640 1280)

# quality & compression settings
Q=60
CLEVEL=6
FPS=12
LOOP=0

# output folder
mkdir -p optimized

for src in *.webp; do
  base="${src%.webp}"
  for w in "${WIDTHS[@]}"; do
    out="optimized/${base}-${w}.webp"
    echo "Generating ${out}…"
    ffmpeg -y \
      -i "$src" \
      -vf "scale=${w}:-1:flags=lanczos,fps=${FPS}" \
      -c:v libwebp \
      -q:v "${Q}" \
      -compression_level "${CLEVEL}" \
      -loop "${LOOP}" \
      "$out"
  done
done
