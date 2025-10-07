#!/usr/bin/env bash
set -e
shopt -s nullglob

# Get absolute path of the folder this script is in
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

# Only look for .gif files directly inside this directory
SRC_DIR="$BASEDIR"

# Output folder: ./mp4 relative to this script
OUTPUT_DIR="$BASEDIR/mp4"

# Define target widths
WIDTHS=(800)

# Create output directory if missing
mkdir -p "$OUTPUT_DIR"

echo "Working directory: $BASEDIR"
echo "Output directory:  $OUTPUT_DIR"

# Process only files that exist *directly in this folder*
for src in "$SRC_DIR"/*.gif; do
  # skip if no matching files
  [ -f "$src" ] || continue

  base="$(basename "$src" .gif)"

  for w in "${WIDTHS[@]}"; do
    out="$OUTPUT_DIR/${base}-${w}.mp4"
    echo "→ Generating $out from $src at ${w}px…"

    ffmpeg -y -i "$src" \
      -vf "scale=${w}:-2:flags=lanczos,fps=12" \
      -c:v libx264 \
      -preset slow \
      -crf 18 \
      -tune animation \
      -pix_fmt yuv420p \
      -movflags +faststart \
      -an \
      "$out"
  done
done