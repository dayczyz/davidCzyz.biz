#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Work in the folder the script lives in
cd "$(dirname "$0")"
ROOT="$(pwd -P)"

# ---- Config (override via env when you run it) ----
OUT_MP4_DIR="${OUT_MP4_DIR:-./mp4}"
OUT_WEBM_DIR="${OUT_WEBM_DIR:-./webm}"

# Use one or more heights; "orig" keeps source size
# Examples when running:
#   HEIGHTS="400 720" ./encode-here.sh
#   HEIGHTS="400 750" ./encode-here.sh
#   HEIGHTS="orig"     ./encode-here.sh
HEIGHTS=(${HEIGHTS:-orig})

FPS="${FPS:-20}"                 # web-safe cadence you liked
CRF_H264="${CRF_H264:-16}"
PRESET_H264="${PRESET_H264:-veryslow}"

CRF_VP9="${CRF_VP9:-24}"         # lower = higher quality
CPU_USED_VP9="${CPU_USED_VP9:-0}" # 0 = best quality (slow)
TILE_COLS_VP9="${TILE_COLS_VP9:-2}"
GOP_VP9="${GOP_VP9:-240}"

# H.264 tuning — protect linework & the critical red
X264_PARAMS='colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:aq-mode=3:aq-strength=1.10:chroma-qp-offset=-3:deblock=-1,-1'

mkdir -p "$OUT_MP4_DIR" "$OUT_WEBM_DIR"

# Build the shared color/scale filter; pass target height or "orig"
vf_chain () {
  local H="$1"
  if [[ "$H" == "orig" ]]; then
    # keep size; enforce even dims for 4:2:0
    printf 'format=gbrp,zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2'
  else
    # keep aspect; width auto, height fixed, even dims
    printf 'format=gbrp,zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=-2:%s:flags=lanczos,format=yuv420p' "$H"
  fi
}

encode_one () {
  local src="$1"                    # e.g., ./15_TR_Way_To_Omoji_2.gif
  local stem="${src%.gif}"          # drop extension
  local base="$(basename "$stem")"  # filename without ext

  for H in "${HEIGHTS[@]}"; do
    local suffix=""
    [[ "$H" != "orig" ]] && suffix="-h$H"

    # MP4
    local out_mp4="$OUT_MP4_DIR/${base}${suffix}.mp4"
    echo "→ MP4  $src  ${suffix:-@src}"
    ffmpeg -v warning -y -r "$FPS" -i "$src" \
      -vf "$(vf_chain "$H")" \
      -c:v libx264 -pix_fmt yuv420p -preset "$PRESET_H264" -crf "$CRF_H264" -tune animation \
      -x264-params "$X264_PARAMS" \
      -movflags +faststart -an \
      -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
      "$out_mp4"

    # WEBM (VP9)
    local out_webm="$OUT_WEBM_DIR/${base}${suffix}.webm"
    echo "→ WEBM $src  ${suffix:-@src}"
    ffmpeg -v warning -y -r "$FPS" -i "$src" \
      -vf "$(vf_chain "$H")" \
      -c:v libvpx-vp9 -pix_fmt yuv420p -b:v 0 -crf "$CRF_VP9" \
      -quality good -cpu-used "$CPU_USED_VP9" -row-mt 1 \
      -tile-columns "$TILE_COLS_VP9" -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
      -g "$GOP_VP9" -an \
      -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
      "$out_webm"
  done
}

# Encode every GIF in *this* folder (no recursion, no path games)
gifs=( ./*.gif )
if (( ${#gifs[@]} == 0 )); then
  echo "No .gif files found in: $ROOT"
  exit 0
fi

for gif in "${gifs[@]}"; do
  encode_one "$gif"
done

echo "Done in: $ROOT"