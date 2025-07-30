#!/usr/bin/env bash
#
# build-static-webp.sh — generate 600, 640, 800, 1100-wide static WebPs

# 1) your target widths
WIDTHS=(600 640 800 1100)

# 2) output dir
mkdir -p optimized

# 3) glob your source rasters
for src in *.jpg *.jpeg *.png; do
  [ -f "$src" ] || continue
  base="${src%.*}"

  for w in "${WIDTHS[@]}"; do
    out="optimized/${base}-${w}.webp"
    echo "→ static ${out}"

    # simple resize + quality
    magick "$src" \
      -filter Lanczos \
      -resize "${w}x" \
      -quality 90 \
      "$out"
  done
done