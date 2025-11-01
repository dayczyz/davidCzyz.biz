#!/usr/bin/env bash
# gif_to_thumbnail_mp4.sh
# Per .gif -> thumb/<name>.thumb.mp4
# • Target canvas 800x519 (encoded 800x520 for even height)
# • Phone scaled to PHONE_W (default 225px)
# • Keeps original timing and end lag
# • Caps total output to 185 frames

set -euo pipefail
shopt -s nullglob

# ---------- Paths ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/thumb}"
mkdir -p "$OUT_DIR"

# ---------- Canvas / Phone ----------
REQ_CANVAS_W=800
REQ_CANVAS_H=519
CANVAS_W=$((REQ_CANVAS_W - (REQ_CANVAS_W % 2)))
CANVAS_H=$((REQ_CANVAS_H + (REQ_CANVAS_H % 2)))  # 519 → 520
PHONE_W="${PHONE_W:-225}"

# ---------- Encoding knobs ----------
CRF_H264="${CRF_H264:-23}"
H264_PRESET="${H264_PRESET:-medium}"
FPS_LIMIT="${FPS_LIMIT:-0}"          # 0 = keep source fps
FRAMES_CAP="${FRAMES_CAP:-185}"      # <-- 185 total frames
OVERWRITE="${OVERWRITE:-0}"

# ---------- Whirlpool yellow + optional compensation ----------
BG_R=238; BG_G=177; BG_B=18
MP4_YELLOW_COMP="${MP4_YELLOW_COMP:-1}"
MP4_COMP_R="${MP4_COMP_R:--2}"
MP4_COMP_G="${MP4_COMP_G:--8}"
MP4_COMP_B="${MP4_COMP_B:-0}"

if [[ "$MP4_YELLOW_COMP" == "1" ]]; then
  COMP_R=$((BG_R + MP4_COMP_R))
  COMP_G=$((BG_G + MP4_COMP_G))
  COMP_B=$((BG_B + MP4_COMP_B))
  (( COMP_R < 0 )) && COMP_R=0; (( COMP_R > 255 )) && COMP_R=255
  (( COMP_G < 0 )) && COMP_G=0; (( COMP_G > 255 )) && COMP_G=255
  (( COMP_B < 0 )) && COMP_B=0; (( COMP_B > 255 )) && COMP_B=255
else
  COMP_R=$BG_R; COMP_G=$BG_G; COMP_B=$BG_B
fi
printf -v BG_HEX "#%02X%02X%02X" "$COMP_R" "$COMP_G" "$COMP_B"
BG_HEX_0X="${BG_HEX/#\#/0x}"

# ---------- Helpers ----------
exists_and_skip () { [[ "$OVERWRITE" != "1" && -f "$1" ]]; }
fps_stage () { (( FPS_LIMIT > 0 )) && printf "fps=%s," "$FPS_LIMIT" || true; }

vf_thumb () {
  # No trim or retime — preserve source slowdown.
  printf "[0:v]%sformat=rgba," "$(fps_stage)"
  printf "scale=w=%s:h=-2:flags=lanczos:force_divisible_by=2[fg];" "$PHONE_W"
  printf "color=c=%s:s=%sx%s[bg];" "$BG_HEX_0X" "$CANVAS_W" "$CANVAS_H"
  printf "[bg][fg]overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2:format=auto,"
  printf "format=yuv420p"
}

encode_mp4 () {
  local in="$1" out="$2" vf="$3"
  ffmpeg -nostdin -v error -stats -y -hide_banner \
    -i "$in" -frames:v "$FRAMES_CAP" \
    -filter_complex "$vf" \
    -c:v libx264 -crf "$CRF_H264" -preset "$H264_PRESET" -profile:v high -level 4.1 \
    -pix_fmt yuv420p -movflags +faststart \
    -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709" \
    -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
    "$out"
}

# ---------- MAIN ----------
found_any=0
for gif in "$SRC_DIR"/*.gif; do
  [[ -e "$gif" ]] || break
  found_any=1
  base="$(basename "$gif")"
  stem="${base%.*}"
  out="$OUT_DIR/${stem}.thumb.mp4"

  echo ">>> $base"
  echo "  Canvas : ${CANVAS_W}x${CANVAS_H} (bg ${BG_HEX})"
  echo "  Phone  : width ${PHONE_W}px (AR preserved)"
  echo "  Frames : capped at ${FRAMES_CAP} (keeps end lag)"
  echo "  Output : $out"

  if exists_and_skip "$out"; then
    echo "  ↪︎ Skip existing: $out"
  else
    encode_mp4 "$gif" "$out" "$(vf_thumb)"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "⚠️  No .gif files found in $SRC_DIR"
fi
