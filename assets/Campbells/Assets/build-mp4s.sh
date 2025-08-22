#!/usr/bin/env bash
set -euo pipefail

# ---- Config ----
SRC_DIR="/Assets/"          # change if needed
OUTPUT_DIR="/accurateMp4"    # change if needed
WIDTHS=(1000)                        # add more widths if you like, e.g. (640 1000 1500)
FPS="${FPS:-12}"                     # keep your current 12 fps; override with env if desired
CRF="${CRF:-16}"                     # a bit stronger than 18 for flat art
PRESET="${PRESET:-veryslow}"         # quality > speed; change to "slow" if needed

# x264 tuning to keep flat fills & linework crisp
X264_PARAMS='colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:aq-mode=3:aq-strength=1.10:chroma-qp-offset=-2:deblock=-1,-1'

mkdir -p "$OUTPUT_DIR"

for src in "$SRC_DIR"/*.gif; do
  [ -f "$src" ] || continue
  base="$(basename "$src" .gif)"
  for w in "${WIDTHS[@]}"; do
    out="$OUTPUT_DIR/${base}-${w}.mp4"
    echo "→ Generating $out from $src at ${w}px…"

    ffmpeg -v warning -y -i "$src" \
      -vf "format=gbrp,\
zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,\
scale=${w}:-2:flags=lanczos,fps=${FPS},format=yuv420p" \
      -c:v libx264 -preset "$PRESET" -crf "$CRF" -tune animation -pix_fmt yuv420p \
      -x264-params "$X264_PARAMS" \
      -movflags +faststart -an \
      -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
      "$out"
  done
done