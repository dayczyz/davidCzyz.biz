
#!/usr/bin/env bash
# gif_to_transparent_video.sh
#
# Outputs per .gif:
#   webm/<name>.webm         (FULL 900x1788, transparent VP9, exact canvas)
#   webm/<name>.small.webm   (SMALL 400w, height auto, transparent VP9)
#   mp4/<name>.mp4           (FULL 1200xAUTO, opaque over Whirlpool yellow)
#   mp4/<name>.small.mp4     (SMALL 400xAUTO, opaque over Whirlpool yellow)
#   poster/<name>.webp       (first frame, 1200w x auto)
#
# Controls (env overrides):
#   FRAMES_CAP=122, FPS_LIMIT=0, OVERWRITE=0
#   CRF_WEBM_FULL=22, CRF_WEBM_SMALL=26
#   CRF_H264_FULL=20, CRF_H264_SMALL=23, H264_PRESET=medium
#   MP4_YELLOW_COMP=1   # 1 = apply pre-bias to hit 238,177,18 after encode
#   MP4_COMP_R=-2 MP4_COMP_G=-8 MP4_COMP_B=0  # fine-tune deltas (ints)
#
# Notes:
# - WebM keeps alpha (yuva420p). No background added.
# - MP4 composites over Whirlpool yellow; whites preserved.
# - -nostdin prevents accidental interactive input from breaking runs.

set -euo pipefail
shopt -s nullglob

# ---------- Paths ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR}"
OUT_WEBM_DIR="${OUT_WEBM_DIR:-$SCRIPT_DIR/webm}"
OUT_MP4_DIR="${OUT_MP4_DIR:-$SCRIPT_DIR/mp4}"
OUT_POSTER_DIR="${OUT_POSTER_DIR:-$SCRIPT_DIR/poster}"
mkdir -p "$OUT_WEBM_DIR" "$OUT_MP4_DIR" "$OUT_POSTER_DIR"

# ---------- Dimensions ----------
FULL_W=900
FULL_H=1788
SMALL_WEBM_W=400

MP4_FULL_W=1200
MP4_FULL_H=$(( (MP4_FULL_W * FULL_H + FULL_W/2) / FULL_W ))
(( MP4_FULL_H % 2 == 1 )) && MP4_FULL_H=$((MP4_FULL_H + 1))

MP4_SMALL_W=400
MP4_SMALL_H=$(( (MP4_SMALL_W * FULL_H + FULL_W/2) / FULL_W ))
(( MP4_SMALL_H % 2 == 1 )) && MP4_SMALL_H=$((MP4_SMALL_H + 1))

POSTER_W=1200

# ---------- Encoding knobs ----------
CRF_WEBM_FULL="${CRF_WEBM_FULL:-22}"
CRF_WEBM_SMALL="${CRF_WEBM_SMALL:-26}"
CRF_H264_FULL="${CRF_H264_FULL:-20}"
CRF_H264_SMALL="${CRF_H264_SMALL:-23}"
H264_PRESET="${H264_PRESET:-medium}"

FPS_LIMIT="${FPS_LIMIT:-0}"
FRAMES_CAP="${FRAMES_CAP:-122}"   # <-- hard default to 122
OVERWRITE="${OVERWRITE:-0}"

# ---------- Whirlpool yellow + optional compensation (MP4 only) ----------
# Target RGB is 238,177,18 (#EEB112). Encoders can push green up on some stacks.
BG_R=238; BG_G=177; BG_B=18
MP4_YELLOW_COMP="${MP4_YELLOW_COMP:-1}"     # default ON
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

trim_cli () {
  # CLI-level cap (backup to filter-level trim)
  if (( FRAMES_CAP > 0 )); then
    printf -- "-frames:v %d" "$FRAMES_CAP"
  fi
}

# returns 'fps=...,'
fps_stage () {
  if (( FPS_LIMIT > 0 )); then
    printf "fps=%s," "$FPS_LIMIT"
  fi
}

# returns 'trim=end_frame=N,setpts=PTS-STARTPTS,'
trim_stage () {
  if (( FRAMES_CAP > 0 )); then
    printf "trim=end_frame=%d,setpts=PTS-STARTPTS," "$FRAMES_CAP"
  fi
}

# --------- FILTERS ---------
vf_webm_full () {
  local W="$1" H="$2"
  printf "[0:v]%sformat=rgba," "$(fps_stage)"
  printf "scale=w=%s:h=%s:force_original_aspect_ratio=decrease:flags=lanczos,setsar=1," "$W" "$H"
  printf "pad=%s:%s:(%s-iw)/2:(%s-ih)/2:color=black@0," "$W" "$H" "$W" "$H"
  printf "%s" "$(trim_stage)"
  printf "format=yuva420p"
}

vf_webm_small () {
  local W="$1"
  printf "[0:v]%sformat=rgba," "$(fps_stage)"
  printf "scale=w=%s:h=-2:flags=lanczos,setsar=1," "$W"
  printf "%s" "$(trim_stage)"
  printf "format=yuva420p"
}

vf_mp4_opaque () {
  local W="$1" H="$2"
  printf "[0:v]%sformat=rgba," "$(fps_stage)"
  printf "scale=w=%s:h=%s:force_original_aspect_ratio=decrease:flags=lanczos,setsar=1[fg];" "$W" "$H"
  printf "color=c=%s:s=%sx%s[bg];" "$BG_HEX_0X" "$W" "$H"
  printf "[bg][fg]overlay=x=(main_w-overlay_w)/2:y=(main_h-overlay_h)/2:format=auto,"
  printf "%s" "$(trim_stage)"
  printf "format=yuv420p"
}

# --------- ENCODERS (all with -nostdin) ---------
encode_webm () {
  local in="$1" out="$2" crf="$3" vf="$4"
  ffmpeg -nostdin -v error -stats -y -hide_banner \
    -i "$in" $(trim_cli) \
    -filter_complex "$vf" \
    -c:v libvpx-vp9 -crf "$crf" -b:v 0 -row-mt 1 -threads 0 \
    -auto-alt-ref 0 \
    -pix_fmt yuva420p \
    "$out"
}

encode_mp4 () {
  local in="$1" out="$2" vf="$3" crf="$4"
  ffmpeg -nostdin -v error -stats -y -hide_banner \
    -i "$in" $(trim_cli) \
    -filter_complex "$vf" \
    -c:v libx264 -crf "$crf" -preset "$H264_PRESET" -profile:v high -level 4.1 \
    -pix_fmt yuv420p -movflags +faststart \
    -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709" \
    -colorspace bt709 -color_primaries bt709 -color_trc bt709 -color_range tv \
    "$out"
}

encode_poster () {
  local in="$1" out="$2"
  ffmpeg -nostdin -v error -y -hide_banner \
    -i "$in" -frames:v 1 \
    -vf "scale=${POSTER_W}:-1:flags=lanczos" \
    -c:v libwebp -lossless 0 -q:v 85 \
    "$out"
}

# ---------- MAIN ----------
found_any=0
for gif in "$SRC_DIR"/*.gif; do
  [[ -e "$gif" ]] || break
  found_any=1
  base="$(basename "$gif")"
  stem="${base%.*}"

  webm_full="$OUT_WEBM_DIR/${stem}.webm"
  webm_small="$OUT_WEBM_DIR/${stem}.small.webm"
  mp4_full="$OUT_MP4_DIR/${stem}.mp4"
  mp4_small="$OUT_MP4_DIR/${stem}.small.mp4"
  poster="$OUT_POSTER_DIR/${stem}.webp"

  echo ">>> $base"
  echo "  WEBM full     : ${FULL_W}x${FULL_H} (transparent, exact canvas)"
  echo "  WEBM small    : ${SMALL_WEBM_W}w x auto (transparent)"
  echo "  MP4 full      : ${MP4_FULL_W}x${MP4_FULL_H} (opaque over target 238,177,18; using ${BG_HEX})"
  echo "  MP4 small     : ${MP4_SMALL_W}x${MP4_SMALL_H} (same background)"
  echo "  Poster (webp) : ${POSTER_W}w x auto from first frame"

  if exists_and_skip "$webm_full"; then echo "  ↪︎ Skip existing: $webm_full"; else
    encode_webm "$gif" "$webm_full" "$CRF_WEBM_FULL" "$(vf_webm_full "$FULL_W" "$FULL_H")"
  fi

  if exists_and_skip "$webm_small"; then echo "  ↪︎ Skip existing: $webm_small"; else
    encode_webm "$gif" "$webm_small" "$CRF_WEBM_SMALL" "$(vf_webm_small "$SMALL_WEBM_W")"
  fi

  if exists_and_skip "$mp4_full"; then echo "  ↪︎ Skip existing: $mp4_full"; else
    encode_mp4 "$gif" "$mp4_full" "$(vf_mp4_opaque "$MP4_FULL_W" "$MP4_FULL_H")" "$CRF_H264_FULL"
  fi

  if exists_and_skip "$mp4_small"; then echo "  ↪︎ Skip existing: $mp4_small"; else
    encode_mp4 "$gif" "$mp4_small" "$(vf_mp4_opaque "$MP4_SMALL_W" "$MP4_SMALL_H")" "$CRF_H264_SMALL"
  fi

  if exists_and_skip "$poster"; then echo "  ↪︎ Skip existing: $poster"; else
    encode_poster "$gif" "$poster"
  fi
done

if [[ "$found_any" -eq 0 ]]; then
  echo "⚠️  No .gif files found in $SRC_DIR"
fi
