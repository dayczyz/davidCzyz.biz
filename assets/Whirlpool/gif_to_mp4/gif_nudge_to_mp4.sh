#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------
# Nudge GIF palette → encode high-fidelity MP4
# - Keeps original GIF frame rate (no fps override)
# - Edits ONLY the palette (surgical, non-destructive)
# - MP4 master: H.264 4:4:4 10-bit, Rec.709 tagged
# --------------------------------------------

# ---------- USER SETTINGS ----------
# Target colors
TARGET_YELLOW="rgb(249,173,0)"
TARGET_BLACK="rgb(23,23,23)"
TARGET_WHITE="rgb(255,255,255)"

# What to replace (your current GIF’s approx values)
SOURCE_YELLOW="rgb(239,173,18)"   # add more below if needed

# Tolerances (adjust if too few/too many pixels are caught)
FUZZ_YELLOW="8%"   # widen to 9–10% if some yellows don't catch
FUZZ_WHITE="3%"
FUZZ_BLACK="5%"

# x264 quality settings
CRF_MASTER=16      # lower = higher quality (e.g., 14–18 good range)
X264_PRESET="slow" # ultrafast..placebo
# -----------------------------------

# ---- dependencies check ----
command -v ffmpeg >/dev/null  || { echo "ffmpeg not found"; exit 1; }
command -v magick >/dev/null  || { echo "ImageMagick (magick) not found"; exit 1; }

# ---- args / IO ----
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 input.gif [output_dir]"
  exit 1
fi
IN_GIF="$1"
OUT_DIR="${2:-./out}"
mkdir -p "$OUT_DIR"

BASE="$(basename "${IN_GIF%.*}")"
PALETTE="${OUT_DIR}/${BASE}_palette.png"
PALETTE_TUNED="${OUT_DIR}/${BASE}_palette_tuned.png"
TUNED_GIF="${OUT_DIR}/${BASE}_tuned.gif"
MP4_MASTER="${OUT_DIR}/${BASE}_master_44410.mp4"

echo ">>> Input GIF: $IN_GIF"
echo ">>> Output dir: $OUT_DIR"

# 1) Extract a single global palette (preserve original timing)
echo ">>> Generating palette"
ffmpeg -y -i "$IN_GIF" -vf "palettegen=stats_mode=single" "$PALETTE"

# 2) Tune palette colors (surgical edits)
#    - Nudge yellows to target
#    - Snap near-whites to pure white
#    - Snap near-blacks to target black (23,23,23)
echo ">>> Tuning palette colors"
magick "$PALETTE" \
  -fuzz "$FUZZ_YELLOW" -fill "$TARGET_YELLOW" -opaque "$SOURCE_YELLOW" \
  -fuzz "$FUZZ_WHITE"  -fill "$TARGET_WHITE"  -opaque white \
  -fuzz "$FUZZ_BLACK"  -fill "$TARGET_BLACK"  -opaque black \
  "$PALETTE_TUNED"

# If your GIF has multiple “almost yellow” shades, add more lines like:
#   -fuzz 7% -fill "$TARGET_YELLOW" -opaque "rgb(246,178,20)" \
# right before "$PALETTE_TUNED" above.

# 3) Remap GIF to tuned palette with quality dithering
echo ">>> Remapping GIF to tuned palette"
ffmpeg -y -i "$IN_GIF" -i "$PALETTE_TUNED" \
  -lavfi "paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
  "$TUNED_GIF"

# 4) Encode a high-fidelity MP4 (Rec.709, 444 10-bit, tagged)
# NOTE: Your ffmpeg build expects 'trc=' (not 'transfer=') for the colorspace filter.
echo ">>> Encoding 444 10-bit MP4 (Rec.709 tagged)"
ffmpeg -y -i "$TUNED_GIF" \
  -vf "colorspace=space=bt709:primaries=bt709:trc=bt709:format=yuv444p10le:fast=1" \
  -c:v libx264 -pix_fmt yuv444p10le -crf "$CRF_MASTER" -preset "$X264_PRESET" \
  -profile:v high444 -level 5.1 \
  -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709:range=tv" \
  -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
  -movflags +faststart \
  "$MP4_MASTER"

echo ">>> Done."
echo "GIF (tuned):   $TUNED_GIF"
echo "MP4 (master):  $MP4_MASTER"
