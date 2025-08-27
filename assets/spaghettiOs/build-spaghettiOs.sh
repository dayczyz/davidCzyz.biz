#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Defaults (override at run time) ----
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR}"             # root containing GIFs (spaghettiOs)
OUT_MP4_DIR="${OUT_MP4_DIR:-$SCRIPT_DIR/mp4}"
OUT_WEBM_DIR="${OUT_WEBM_DIR:-$SCRIPT_DIR/webm}"

FPS="${FPS:-20}"
CRF_H264="${CRF_H264:-16}"
PRESET_H264="${PRESET_H264:-veryslow}"

CRF_VP9="${CRF_VP9:-24}"
CPU_USED_VP9="${CPU_USED_VP9:-0}"
TILE_COLS_VP9="${TILE_COLS_VP9:-2}"
GOP_VP9="${GOP_VP9:-240}"

# Section-specific heights
BIGMATRIX_HEIGHTS=(${BIGMATRIX_HEIGHTS:-400 720})
APRILFOOLS_HEIGHTS=(${APRILFOOLS_HEIGHTS:-400 720})
QUADMATRIX_HEIGHTS=(${QUADMATRIX_HEIGHTS:-400 750})
HEADER_HEIGHTS=(${HEADER_HEIGHTS:-400 720})

# H.264 tuning — protect linework/chroma (red fidelity)
X264_PARAMS='colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:aq-mode=3:aq-strength=1.10:chroma-qp-offset=-3:deblock=-1,-1'

mkout() { mkdir -p "$1"; }

# Canonicalize SRC_DIR to avoid prefix-mismatch issues (symlinks, etc.)
pushd "$SRC_DIR" >/dev/null
SRC_DIR_ABS="$(pwd -P)"
popd >/dev/null

echo "SRC_DIR=$SRC_DIR_ABS"
echo "OUT_MP4_DIR=$OUT_MP4_DIR"
echo "OUT_WEBM_DIR=$OUT_WEBM_DIR"
mkout "$OUT_MP4_DIR"; mkout "$OUT_WEBM_DIR"

# Build the shared color/scale filter; pass target height or "orig"
vf_chain () {
  local H="$1"
  if [[ "$H" == "orig" ]]; then
    printf 'format=gbrp,zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,format=yuv420p'
  else
    printf 'format=gbrp,zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=-2:%s:flags=lanczos,format=yuv420p' "$H"
  fi
}

encode_mp4 () {
  local src="$1" out="$2" height="$3"
  ffmpeg -v warning -y -r "$FPS" -i "$src" \
    -vf "$(vf_chain "$height")" \
    -c:v libx264 -pix_fmt yuv420p -preset "$PRESET_H264" -crf "$CRF_H264" -tune animation \
    -x264-params "$X264_PARAMS" \
    -movflags +faststart -an \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    "$out"
}

encode_webm () {
  local src="$1" out="$2" height="$3"
  ffmpeg -v warning -y -r "$FPS" -i "$src" \
    -vf "$(vf_chain "$height")" \
    -c:v libvpx-vp9 -pix_fmt yuv420p -b:v 0 -crf "$CRF_VP9" \
    -quality good -cpu-used "$CPU_USED_VP9" -row-mt 1 \
    -tile-columns "$TILE_COLS_VP9" -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
    -g "$GOP_VP9" -an \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    "$out"
}

# Walk GIFs recursively (stable order)
while IFS= read -r -d '' src; do
  # Canonical absolute path for the found file
  src_abs="$(cd "$(dirname "$src")" && pwd -P)/$(basename "$src")"

  # Compute path relative to SRC_DIR_ABS safely
  rel="$src_abs"
  if [[ "$src_abs" == "$SRC_DIR_ABS/"* ]]; then
    rel="${src_abs:${#SRC_DIR_ABS}+1}"
  fi

  stem_noext="${rel%.*}"
  dir_rel="$(dirname "$stem_noext")"
  base_rel="$(basename "$stem_noext")"

  # Pick height set based on folder
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
done < <(find "$SRC_DIR_ABS" -type f -iname '*.gif' -print0 | sort -z)
