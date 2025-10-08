#!/usr/bin/env bash
# convert-gif-to-mp4.sh
# Converts ONLY .gif files located in the SAME folder as this script.
# Outputs both web-safe (yuv420p) and high-fidelity (yuv444p) MP4s per width.

set -euo pipefail
shopt -s nullglob

# --- lock to this script's directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- settings you can tweak ---
WIDTHS=(1200)              # e.g., (640 1000 1500)
FPS="${FPS:-20}"           # GIF-like cadence
CRF_420="${CRF_420:-16}"   # lower = higher quality (typical 16–20)
CRF_444="${CRF_444:-12}"   # keep 444 extra clean
PRESET="${PRESET:-slow}"   # slow/veryslow if you can afford it

OUT_DIR="$SCRIPT_DIR/mp4"
mkdir -p "$OUT_DIR"

# Conservative x264 knobs to protect flats/edges; signal bt709 correctly
X264_COMMON="colorprim=bt709:transfer=bt709:colormatrix=bt709:videoformat=component:range=limited:aq-mode=3:aq-strength=1.1:deblock=-1,-1"

echo "Converting .gif files in: $SCRIPT_DIR"
echo "Output: $OUT_DIR"
echo "Widths: ${WIDTHS[*]}  FPS=$FPS  PRESET=$PRESET"

command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found"; exit 1; }

for src in "$SCRIPT_DIR"/*.gif; do
  [ -f "$src" ] || continue
  base="$(basename "$src" .gif)"
  for w in "${WIDTHS[@]}"; do
    out420="$OUT_DIR/${base}-${w}-420.mp4"
    out444="$OUT_DIR/${base}-${w}-444.mp4"

    echo "→ $base @ ${w}px (420 + 444)"

    # Pipeline notes:
    # 1) Read GIF → RGB
    # 2) Scale in RGB (Lanczos) to avoid chroma bleed on edges/flat fills
    # 3) Convert to bt709 limited with error-diffusion dithering before YUV
    # 4) For 420: format yuv420p; for 444: format yuv444p

    # --- Web-safe 4:2:0 ---
    ffmpeg -v warning -y -i "$src" \
      -vf "format=gbrp, \
           fps=${FPS}, \
           scale=${w}:-2:flags=lanczos+accurate_rnd+full_chroma_int, \
           zscale=primaries=bt709:transfer=bt709:range=limited:dither=error_diffusion, \
           format=yuv420p" \
      -c:v libx264 -preset "$PRESET" -crf "$CRF_420" -tune animation \
      -x264-params "$X264_COMMON" \
      -movflags +faststart \
      -an \
      -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
      "$out420"

    # --- High-fidelity 4:4:4 (desktop-first) ---
    ffmpeg -v warning -y -i "$src" \
      -vf "format=gbrp, \
           fps=${FPS}, \
           scale=${w}:-2:flags=lanczos+accurate_rnd+full_chroma_int, \
           zscale=primaries=bt709:transfer=bt709:range=limited:dither=error_diffusion, \
           format=yuv444p" \
      -c:v libx264 -preset "$PRESET" -crf "$CRF_444" -tune animation \
      -pix_fmt yuv444p \
      -x264-params "$X264_COMMON:profile=high444" \
      -movflags +faststart \
      -an \
      -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
      "$out444"
  done
done
