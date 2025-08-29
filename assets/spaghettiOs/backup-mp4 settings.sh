#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Defaults (override at run time) ----
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR}"             # root containing GIFs (spaghettiOs)
OUT_MP4_DIR="${OUT_MP4_DIR:-$SCRIPT_DIR/mp4}" # outputs mirror source structure
OUT_WEBM_DIR="${OUT_WEBM_DIR:-$SCRIPT_DIR/webm}"

FPS="${FPS:-20}"

# H.264 (MP4)
CRF_H264="${CRF_H264:-16}"
PRESET_H264="${PRESET_H264:-veryslow}"

# VP9 (WEBM)
CRF_VP9="${CRF_VP9:-24}"          # lower = higher quality
CPU_USED_VP9="${CPU_USED_VP9:-0}" # 0 = best quality (slow)
TILE_COLS_VP9="${TILE_COLS_VP9:-2}"
GOP_VP9="${GOP_VP9:-240}"

# Section-specific heights (px). Others default to original size.
BIGMATRIX_HEIGHTS=(${BIGMATRIX_HEIGHTS:-400 720})
APRILFOOLS_HEIGHTS=(${APRILFOOLS_HEIGHTS:-400 720})
QUADMATRIX_HEIGHTS=(${QUADMATRIX_HEIGHTS:-400 750})
HEADER_HEIGHTS=(${HEADER_HEIGHTS:-400 720})

# H.264 tuning — protect linework/chroma (red fidelity)
X264_PARAMS='colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:aq-mode=3:aq-strength=1.10:chroma-qp-offset=-3:deblock=-1,-1'

mkout() { mkdir -p "$1"; }

# Canonicalize roots and create outputs
cd "$SRC_DIR"
SRC_DIR_ABS="$(pwd -P)"
mkout "$OUT_MP4_DIR"; mkout "$OUT_WEBM_DIR"

echo "SRC_DIR=$SRC_DIR_ABS"
echo "OUT_MP4_DIR=$OUT_MP4_DIR"
echo "OUT_WEBM_DIR=$OUT_WEBM_DIR"

# Shared color/scale filter; pass target height or "orig".
# Ensures even dimensions for 4:2:0.
vf_chain () {
  local H="$1"
  if [[ "$H" == "orig" ]]; then
    printf 'format=gbrp,zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2'
  else
    printf 'format=gbrp,zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=-2:%s:flags=lanczos,format=yuv420p' "$H"
  fi
}

encode_mp4 () {
  local src_abs="$1" out="$2" height="$3"
  ffmpeg -v warning -y -r "$FPS" -i "$src_abs" \
    -vf "$(vf_chain "$height")" \
    -c:v libx264 -pix_fmt yuv420p -preset "$PRESET_H264" -crf "$CRF_H264" -tune animation \
    -x264-params "$X264_PARAMS" \
    -movflags +faststart -an \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    "$out"
}

encode_webm () {
  local src_abs="$1" out="$2" height="$3"
  ffmpeg -v warning -y -r "$FPS" -i "$src_abs" \
    -vf "$(vf_chain "$height")" \
    -c:v libvpx-vp9 -pix_fmt yuv420p -b:v 0 -crf "$CRF_VP9" \
    -quality good -cpu-used "$CPU_USED_VP9" -row-mt 1 \
    -tile-columns "$TILE_COLS_VP9" -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
    -g "$GOP_VP9" -an \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    "$out"
}

# Walk GIFs **relative to SRC_DIR**, ignoring output trees.
# NOTE: No 'sort -z' here (BSD sort on macOS breaks with -z).
while IFS= read -r -d '' src_rel; do
  rel="${src_rel#./}"                         # strip leading './'
  rel="${rel//$'\r'/}"                        # scrub any stray CRs just in case
  stem_noext="${rel%.*}"
  dir_rel="$(dirname "$stem_noext")"
  base_rel="$(basename "$stem_noext")"
  src_abs="$SRC_DIR_ABS/$rel"

  # Choose height set based on folder
  heights=("orig")
  case "/$dir_rel/" in
    */bigMatrix/*)   heights=("${BIGMATRIX_HEIGHTS[@]}") ;;
    */aprilFools/*)  heights=("${APRILFOOLS_HEIGHTS[@]}") ;;
    */quadMatrix/*)  heights=("${QUADMATRIX_HEIGHTS[@]}") ;;
    */header/*)      heights=("${HEADER_HEIGHTS[@]}") ;;
  esac

  for H in "${heights[@]}"; do
    suffix=""; [[ "$H" != "orig" ]] && suffix="-h${H}"

    # MP4
    out_dir_mp4="$OUT_MP4_DIR/$dir_rel"; mkout "$out_dir_mp4"
    out_mp4="$out_dir_mp4/${base_rel}${suffix}.mp4"
    echo "→ MP4  ${rel}  ${suffix:-@src}"
    encode_mp4 "$src_abs" "$out_mp4" "$H"

    # WEBM
    out_dir_webm="$OUT_WEBM_DIR/$dir_rel"; mkout "$out_dir_webm"
    out_webm="$out_dir_webm/${base_rel}${suffix}.webm"
    echo "→ WEBM ${rel}  ${suffix:-@src}"
    encode_webm "$src_abs" "$out_webm" "$H"
  done
done < <(find . -type f -iname '*.gif' \
            -not -path './mp4/*' -not -path './webm/*' \
            -print0)
