#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"
OUT_DIR="${OUT_DIR:-./mp4}"
TARGET_W="${TARGET_W:-1200}"
TARGET_H="${TARGET_H:-844}"

# cover | contain | stretch
FIT="${FIT:-cover}"
PAD_COLOR="${PAD_COLOR:-black}"   # used only for contain

# Keep original GIF timing (VFR). To force CFR: FORCE_FPS=20 ./encode-whirlpool.sh
FORCE_FPS="${FORCE_FPS:-}"

# H.264 quality
CRF_H264="${CRF_H264:-16}"
PRESET_H264="${PRESET_H264:-veryslow}"

# --- Yellow protection (enable=1/disable=0) ---
YELLOW_TWEAK="${YELLOW_TWEAK:-1}"
RED_SCALE="${RED_SCALE:-0.996}"     # 239/240
GREEN_SCALE="${GREEN_SCALE:-0.957}" # 177/185
BLUE_SCALE="${BLUE_SCALE:-1.14}"    # 16/14

# Favor chroma & edges (keeps large yellow fields clean)
X264_PARAMS='colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:\
aq-mode=3:aq-strength=1.20:chroma-qp-offset=-4:deblock=-1,-1'

mkdir -p "$OUT_DIR"

# FPS opts
if [[ -n "$FORCE_FPS" ]]; then
  FPS_OPTS=(-fps_mode cfr -r "$FORCE_FPS")
else
  FPS_OPTS=(-fps_mode vfr)
fi

# Build the color tweak (runs in RGB safely)
yellow_filter() {
  if [[ "$YELLOW_TWEAK" == "1" ]]; then
    printf 'colorchannelmixer=rr=%s:gg=%s:bb=%s,' \
      "$RED_SCALE" "$GREEN_SCALE" "$BLUE_SCALE"
  else
    printf ''
  fi
}

# Full filter chain
vf_chain () {
  local tweak; tweak="$(yellow_filter)"
  case "$FIT" in
    cover)
      printf 'format=gbrp,%szscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=%s:%s:flags=lanczos:force_original_aspect_ratio=increase,crop=%s:%s,format=yuv420p,setsar=1' \
        "$tweak" "$TARGET_W" "$TARGET_H" "$TARGET_W" "$TARGET_H"
      ;;
    contain)
      printf 'format=gbrp,%szscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=%s:%s:flags=lanczos:force_original_aspect_ratio=decrease,pad=%s:%s:(ow-iw)/2:(oh-ih)/2:color=%s,format=yuv420p,setsar=1' \
        "$tweak" "$TARGET_W" "$TARGET_H" "$TARGET_W" "$TARGET_H" "$PAD_COLOR"
      ;;
    stretch)
      printf 'format=gbrp,%szscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=%s:%s:flags=lanczos,format=yuv420p,setsar=1' \
        "$tweak" "$TARGET_W" "$TARGET_H"
      ;;
    *) echo "Unknown FIT='$FIT' (use cover|contain|stretch)"; exit 1;;
  esac
}

encode_one () {
  local src="$1"
  local stem="${src%.gif}"
  local base="$(basename "$stem")"
  local out="$OUT_DIR/${base}-${TARGET_W}x${TARGET_H}.mp4"

  echo "→ MP4  $src  →  $out  (FIT=$FIT  YELLOW_TWEAK=$YELLOW_TWEAK)"
  ffmpeg -v warning -y -i "$src" \
    -vf "$(vf_chain)" \
    "${FPS_OPTS[@]}" \
    -c:v libx264 -pix_fmt yuv420p -preset "$PRESET_H264" -crf "$CRF_H264" -tune animation \
    -x264-params "$X264_PARAMS" \
    -movflags +faststart -an \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    "$out"
}

gifs=( ./*.gif )
if (( ${#gifs[@]} == 0 )); then
  echo "No .gif files found here."
  exit 0
fi

for gif in "${gifs[@]}"; do
  encode_one "$gif"
done

echo "Done. Outputs in: $OUT_DIR"
