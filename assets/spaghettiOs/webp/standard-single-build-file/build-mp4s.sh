#!/usr/bin/env bash
set -e
shopt -s nullglob

# where this script lives
BASEDIR="$(cd "$(dirname "$0")" && pwd)"

# source GIFs live alongside this script
SRC_DIR="$BASEDIR"

# put your MP4s in ../mp4
OUTPUT_DIR="$BASEDIR/../mp4"

# tweak to whatever widths you need
WIDTHS=(1000)

mkdir -p "$OUTPUT_DIR"

for src in "$SRC_DIR"/*.gif; do
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
