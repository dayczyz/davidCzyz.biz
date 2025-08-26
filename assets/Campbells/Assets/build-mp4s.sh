#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Resolve the folder this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Defaults (can be overridden at runtime) ----
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR}"            # where your .gif files are
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/mp4}"  # outputs go here
WIDTHS=(1200)                                # e.g., (640 1000 1500)
FPS="${FPS:-20}"                             # Web-safe preset uses 20 fps
CRF="${CRF:-16}"                             # stronger than 18 for flat art
PRESET="${PRESET:-veryslow}"                 # quality > speed

# x264 tuning to keep flat fills & linework crisp
X264_PARAMS='colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:aq-mode=3:aq-strength=1.10:chroma-qp-offset=-2:deblock=-1,-1'

mkdir -p "$OUTPUT_DIR"
echo "SRC_DIR=$SRC_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo "FPS=$FPS  CRF=$CRF  PRESET=$PRESET"

for src in "$SRC_DIR"/*.gif; do
  [ -f "$src" ] || continue
  base="$(basename "$src" .gif)"
  for w in "${WIDTHS[@]}"; do
    out="$OUTPUT_DIR/${base}-${w}.mp4"
    echo "→ Generating $out from $src at ${w}px…"

    ffmpeg -v warning -y -i "$src" \
      -vf "format=gbrp,\
zscale=primariesin=bt709:transferin=bt709:rangein=pc:\
primaries=bt709:transfer=bt709:range=limited,\
scale=${w}:-2:flags=lanczos,fps=${FPS},format=yuv420p" \
      -c:v libx264 -pix_fmt yuv420p -preset "$PRESET" -crf "$CRF" -tune animation \
      -x264-params "$X264_PARAMS" \
      -movflags +faststart -an \
      -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
      "$out"
  done
done
