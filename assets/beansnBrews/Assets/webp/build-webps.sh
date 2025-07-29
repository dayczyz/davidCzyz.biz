#!/usr/bin/env bash
#
# build-webps.sh — generate 500, 640, 800, 1100-wide animated WebPs
# with boosted quality and best-method compression

WIDTHS=(600 640 800 1100)
mkdir -p optimized

for src in *.webp; do
  base="${src%.webp}"
  for w in "${WIDTHS[@]}"; do
    out="optimized/${base}-${w}.webp"
    echo "→ Generating ${out}…"
    magick "$src" \
      -coalesce \
      -resize "${w}x" \
      -quality 85 \
      -define webp:method=6 \
      -define webp:near_lossless=85 \
      -define webp:alpha_quality=100 \
      -layers optimize \
      "$out"
  done
done
