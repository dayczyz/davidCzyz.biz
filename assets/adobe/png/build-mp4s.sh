#!/usr/bin/env bash
set -e
shopt -s nullglob

#———————————————————————————————————————————————————————————————
# Function: Convert master GIFs to H.264 MP4 loops at specified widths
# Usage: process_layout "<src_dir>" "<out_dir>" <width1> [<width2> ...]
#———————————————————————————————————————————————————————————————
process_layout() {
  SRCDIR="$1"
  OUTDIR="$2"
  shift 2
  WIDTHS=("$@")
  mkdir -p "$OUTDIR"

  for src in "$SRCDIR"/*.gif; do
    [ -f "$src" ] || continue
    base=$(basename "$src" .gif)
    for w in "${WIDTHS[@]}"; do
      out="$OUTDIR/${base}-${w}.mp4"
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
}

# Adobe layout (master GIFs → optimized MP4s)
SRC_DIR_ADOBE="assets/adobe/png"
OUTPUT_DIR_ADOBE="mp4"
WIDTHS_ADOBE=(1000)

# Adobe Writers layout
# SRC_DIR_WRITERS="assets/adobeWriterDeck/Assets"
# OUTPUT_DIR_WRITERS="assets/adobeWriterDeck/Assets/mp4"
# WIDTHS_WRITERS=(1000)

# Run both layouts
process_layout "$SRC_DIR_ADOBE"   "$OUTPUT_DIR_ADOBE"   "${WIDTHS_ADOBE[@]}"
# process_layout "$SRC_DIR_WRITERS" "$OUTPUT_DIR_WRITERS" "${WIDTHS_WRITERS[@]}"
