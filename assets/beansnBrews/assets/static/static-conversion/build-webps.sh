#!/usr/bin/env bash
#
# build-static-webp.sh — generate 600, 640, 800, 1100-wide static WebPs
# Processes ONLY files located in the same folder as this script.
# Color fidelity first: lossless WebP to avoid YUV shifts.

set -e
shopt -s nullglob

# 0) lock to the script's own directory
BASEDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$BASEDIR"

# 1) your target widths
WIDTHS=(600 640 800 1100 3000)

# 2) output dir (inside this folder)
OUTPUT_DIR="$BASEDIR/optimized"
mkdir -p "$OUTPUT_DIR"

echo "Processing only images in: $BASEDIR"
echo "Output directory:          $OUTPUT_DIR"

# 3) local JPG/PNG only (no subfolders)
for src in "$BASEDIR"/*.jpg "$BASEDIR"/*.jpeg "$BASEDIR"/*.png; do
  [ -f "$src" ] || continue
  base="$(basename "${src%.*}")"

  for w in "${WIDTHS[@]}"; do
    out="$OUTPUT_DIR/${base}-${w}.webp"
    echo "→ Generating ${out} from ${src} at ${w}px…"

    # COLOR-STRICT PATH:
    # - Preserve embedded ICC/profile (don't strip)
    # - Resize with Lanczos
    # - Encode as *lossless WebP* to avoid YUV subsampling and hue shifts
    magick "$src" \
      -filter Lanczos -resize "${w}x" -type TrueColor \
      -define webp:lossless=true \
      -define webp:method=6 \
      -define webp:exact=true \
      -define webp:alpha-quality=100 \
      "$out"
  done
done
