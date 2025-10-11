#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# ---------------------------------------------------------
# Color-safe FFmpeg pipeline (local folder only) — v1.2
#   • Converts all .mov/.mxf in THIS folder
#   • Does REAL colorspace conversion to Rec.709 G2.4 TV
#   • Makes: 444 10-bit master + 420 web deliverable
#   • Optional: .cube LUT + palette GIF
# ---------------------------------------------------------

# ---------- USER CONFIG ----------
CRF_MASTER=16
CRF_DELIV=18
X264_PRESET="slow"

# If your AE export was authored/viewed in sRGB (gamma ~2.2),
# set this to 1 to convert sRGB → Rec.709 G2.4 explicitly.
ASSUME_INPUT_SRGB=0

# If you KNOW your source video levels are FULL (graphics),
# set FORCE_RANGE to "full". If LIMITED (camera/broadcast), set "limited".
# Leave blank to auto-guess. (Explicit is best when you know.)
FORCE_RANGE="full"

# Optional LUT (.cube) applied AFTER any range/colorspace mapping.
LUT_CUBE=""

# Optional GIF generation
MAKE_GIF=0
GIF_FPS=15
GIF_WIDTH=640
# ---------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/out"
mkdir -p "$OUT_DIR"

command -v ffmpeg >/dev/null || { echo "ffmpeg not found"; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe not found"; exit 1; }

detect_pixfmt() {
  ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt \
    -of default=nw=1 "$1" | awk -F= '/pix_fmt=/{print $2}' || true
}
detect_range() {
  ffprobe -v error -select_streams v:0 -show_entries stream=color_range \
    -of default=nw=1 "$1" | awk -F= '/color_range=/{print $2}' || true
}
is_rgb_pixfmt() {
  local pf="$1"
  [[ "$pf" == *rgb* || "$pf" == *gbrp* || "$pf" == *rgba* || "$pf" == *bgra* || "$pf" == *ya* ]]
}

build_filters() {
  # Build a colorspace pipeline that yields Rec.709 (G2.4) TV-range for target pix_fmt
  local INPUT="$1"
  local TARGET_PIXFMT="$2"   # yuv444p10le or yuv420p
  local DO_RANGE_FOR_DELIV="$3"  # 1 or 0 (deliverable may need range mapping)
  local pf range in_cs

  pf="$(detect_pixfmt "$INPUT")"
  range="$(detect_range "$INPUT")"

  # Decide input colorspace metadata assumptions
  # If the input is RGB-like, we must tell ffmpeg what transfer to assume.
  # sRGB primaries ≈ Rec.709 primaries; difference is mainly transfer (gamma).
  if is_rgb_pixfmt "$pf"; then
    if [[ "$ASSUME_INPUT_SRGB" == "1" ]]; then
      # RGB (sRGB transfer) -> Rec.709 G2.4 
      

process_file() {
  local INPUT="$1"
  local BASE="$(basename "${INPUT%.*}")"
  local MASTER_OUT="$OUT_DIR/${BASE}_master_44410.mp4"
  local DELIV_OUT="$OUT_DIR/${BASE}_deliv_420.mp4"
  local GIF_PALETTE="$OUT_DIR/${BASE}_palette.png"
  local GIF_OUT="$OUT_DIR/${BASE}.gif"

  # We won’t rely on probe tags; we’ll just convert explicitly.
  echo ">>> Processing: $BASE"
  local pixfmt="$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=nw=1 "$INPUT" | sed -n 's/^pix_fmt=//p')"
  local cr="$(ffprobe -v error -select_streams v:0 -show_entries stream=color_range -of default=nw=1 "$INPUT" | sed -n 's/^color_range=//p')"
  echo "    pix_fmt: ${pixfmt:-unknown} | color_range: ${cr:-unknown}"

  # Master: always Rec.709/G2.4 and TV range (standardize for consistency)
  local F_MASTER
  F_MASTER="$(build_cs_filter "yuv444p10le" 1)"

  echo "    → Master encode (709 G2.4, TV, yuv444p10le)"
  ffmpeg -y -i "$INPUT" \
    -vf "$F_MASTER" \
    -c:v libx264 -pix_fmt yuv444p10le -crf "$CRF_MASTER" -preset "$X264_PRESET" \
    -profile:v high444 -level 5.1 \
    -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709:range=tv" \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    -c:a aac -b:a 256k -movflags +faststart \
    "$MASTER_OUT"

  # Deliverable: Rec.709/G2.4, TV range, yuv420p
  # If FORCE_RANGE=full, we’re standardizing to TV anyway by forcing range=tv
  local F_DELIV
  F_DELIV="$(build_cs_filter "yuv420p" 1)"

  echo "    → Deliverable encode (709 G2.4, TV, yuv420p)"
  ffmpeg -y -i "$INPUT" \
    -vf "$F_DELIV" \
    -c:v libx264 -pix_fmt yuv420p -crf "$CRF_DELIV" -preset "$X264_PRESET" \
    -profile:v high -level 4.1 \
    -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709:range=tv" \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    -c:a aac -b:a 192k -movflags +faststart \
    "$DELIV_OUT"

  if [[ "$MAKE_GIF" -eq 1 ]]; then
    echo "    → GIF palette"
    ffmpeg -y -i "$INPUT" \
      -vf "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos,palettegen=stats_mode=full" \
      "$GIF_PALETTE"
    echo "    → GIF render"
    ffmpeg -y -i "$INPUT" -i "$GIF_PALETTE" \
      -filter_complex "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
      "$GIF_OUT"
  fi

  echo "    Done: $BASE"
}

echo ">>> Searching for .mov and .mxf files in $SCRIPT_DIR"
for f in "$SCRIPT_DIR"/*.mov "$SCRIPT_DIR"/*.MOV "$SCRIPT_DIR"/*.mxf "$SCRIPT_DIR"/*.MXF; do
  [[ -e "$f" ]] || continue
  process_file "$f"
done
echo ">>> All files processed. Output in: $OUT_DIR"

      in_cs="colorspace"
    else
      # RGB (assume authored in Rec.709 G2.4)
      in_cs="colorspace=ispace=rgb:iprimaries=bt709:itransfer=bt709"
    fi
  else
    # YUV input. If tags are unknown, colorspace will still normalize to 709.
    in_cs="colorspace="
  fi

  # Range handling:
  # We want final to be TV (limited). If the source is FULL or user forces FULL,
  # convert to TV. If source is already LIMITED, skip this part.
  local range_part=""
  local src_is_full=0
  if [[ -n "$FORCE_RANGE" ]]; then
    [[ "$FORCE_RANGE" =~ [Ff][Uu][Ll][Ll] ]] && src_is_full=1
  else
    [[ "$range" =~ pc ]] && src_is_full=1
  fi
  if [[ "$DO_RANGE_FOR_DELIV" == "1" && "$src_is_full" == "1" ]]; then
    # Apply limited mapping
    range_part=":range=tv"
  else
    # Leave as-is (colorspace will still set 709 primaries/transfer)
    range_part=""
  fi

  # Now target 709 everywhere with chosen pixel format
  # Use fast=1 to avoid super-slow conversions while staying accurate.
  local cs_out="space=bt709:primaries=bt709:transfer=bt709${range_part}:format=${TARGET_PIXFMT}:fast=1"

  # Optional LUT after colorspace mapping (so it sees consistent 709 TV)
  local full
  full="${in_cs}${cs_out}"
  if [[ -n "$LUT_CUBE" && -f "$LUT_CUBE" ]]; then
    echo "${full},lut3d='${LUT_CUBE}'"
  else
    echo "${full}"
  fi
}

process_file() {
  local INPUT="$1"
  local BASENAME="$(basename "${INPUT%.*}")"

  local MASTER_MP4="$OUT_DIR/${BASENAME}_master_44410.mp4"
  local DELIV_MP4="$OUT_DIR/${BASENAME}_deliv_420.mp4"
  local GIF_PALETTE="$OUT_DIR/${BASENAME}_palette.png"
  local GIF_OUT="$OUT_DIR/${BASENAME}.gif"

  echo ">>> Processing: $BASENAME"
  local pf="$(detect_pixfmt "$INPUT")"
  local cr="$(detect_range "$INPUT")"
  echo "    pix_fmt: ${pf:-unknown} | color_range: ${cr:-unknown}"

  # Build explicit colorspace conversions
  local F_MASTER
  F_MASTER="$(build_filters "$INPUT" "yuv444p10le" 0)"
  local F_DELIV
  F_DELIV="$(build_filters "$INPUT" "yuv420p" 1)"

  # --- Master (4:4:4 10-bit) ---
  echo "    → Master encode (explicit 709 G2.4 TV, yuv444p10le)"
  ffmpeg -y -i "$INPUT" \
    -vf "$F_MASTER" \
    -c:v libx264 -pix_fmt yuv444p10le -crf "$CRF_MASTER" -preset "$X264_PRESET" \
    -profile:v high444 -level 5.1 \
    -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709:range=tv" \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    -c:a aac -b:a 256k -movflags +faststart \
    "$MASTER_MP4"

  # --- Deliverable (4:2:0) ---
  echo "    → Deliverable encode (explicit 709 G2.4 TV, yuv420p)"
  ffmpeg -y -i "$INPUT" \
    -vf "$F_DELIV" \
    -c:v libx264 -pix_fmt yuv420p -crf "$CRF_DELIV" -preset "$X264_PRESET" \
    -profile:v high -level 4.1 \
    -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709:range=tv" \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    -c:a aac -b:a 192k -movflags +faststart \
    "$DELIV_MP4"

  # --- Optional GIF ---
  if [[ "$MAKE_GIF" -eq 1 ]]; then
    echo "    → GIF palette"
    ffmpeg -y -i "$INPUT" \
      -vf "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos,palettegen=stats_mode=full" \
      "$GIF_PALETTE"
    echo "    → GIF render"
    ffmpeg -y -i "$INPUT" -i "$GIF_PALETTE" \
      -filter_complex "fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
      "$GIF_OUT"
  fi

  echo "    Done: $BASENAME"
}

echo ">>> Searching for .mov and .mxf files in $SCRIPT_DIR"
for f in "$SCRIPT_DIR"/*.mov "$SCRIPT_DIR"/*.MOV "$SCRIPT_DIR"/*.mxf "$SCRIPT_DIR"/*.MXF; do
  [[ -e "$f" ]] || continue
  process_file "$f"
done
echo ">>> All files processed. Output in: $OUT_DIR"
