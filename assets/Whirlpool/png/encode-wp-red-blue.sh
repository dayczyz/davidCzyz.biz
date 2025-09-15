#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Work in the folder the script lives in
cd "$(dirname "$0")"

# ----- Output & geometry -----
OUT_DIR="${OUT_DIR:-./mp4}"
TARGET_W="${TARGET_W:-1200}"
TARGET_H="${TARGET_H:-844}"
FIT="${FIT:-cover}"                # cover | contain | stretch
PAD_COLOR="${PAD_COLOR:-black}"    # for FIT=contain
mkdir -p "$OUT_DIR"

# ----- Timing -----
# Keep original GIF timing (VFR). To force CFR: FORCE_FPS=20 ./encode-wp-red-blue.sh
FORCE_FPS="${FORCE_FPS:-}"
if [[ -n "$FORCE_FPS" ]]; then
  FPS_OPTS=(-fps_mode cfr -r "$FORCE_FPS")
else
  FPS_OPTS=(-fps_mode vfr)
fi

# ----- Encoder quality -----
CRF_H264="${CRF_H264:-16}"
PRESET_H264="${PRESET_H264:-veryslow}"
X264_PARAMS="colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:aq-mode=3:aq-strength=1.18:chroma-qp-offset=-4:deblock=-1,-1"

# ----- Per-file color tweaks (gentle) -----
# Targets:
#   5_KA_browser_window_v3_4.gif   → brand RED ≈ RGB(179, 43, 54)
#   6_MTG_browser_window_v2-2_2.gif→ brand BLUE ≈ RGB(36, 88, 179)
RED_R_SCALE="${RED_R_SCALE:-1.00}"
RED_G_SCALE="${RED_G_SCALE:-0.94}"
RED_B_SCALE="${RED_B_SCALE:-1.02}"
BLUE_R_SCALE="${BLUE_R_SCALE:-0.95}"
BLUE_G_SCALE="${BLUE_G_SCALE:-1.02}"
BLUE_B_SCALE="${BLUE_B_SCALE:-1.06}"

# ----- Neutral protection -----
WHITE_T="${WHITE_T:-240}"          # >= this on all channels → clamp to pure white
NEUTRAL_MIN="${NEUTRAL_MIN:-230}"  # only affect bright greys
NEUTRAL_DELTA="${NEUTRAL_DELTA:-24}"  # max per-channel difference to count as “near grey”

# Build the geometry / 709-limited part
geo_chain() {
  if [[ "$FIT" == "cover" ]]; then
    echo "zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=${TARGET_W}:${TARGET_H}:flags=lanczos:force_original_aspect_ratio=increase,crop=${TARGET_W}:${TARGET_H}"
  elif [[ "$FIT" == "contain" ]]; then
    echo "zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=${TARGET_W}:${TARGET_H}:flags=lanczos:force_original_aspect_ratio=decrease,pad=${TARGET_W}:${TARGET_H}:(ow-iw)/2:(oh-ih)/2:color=${PAD_COLOR}"
  else
    echo "zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited,scale=${TARGET_W}:${TARGET_H}:flags=lanczos"
  fi
}

# Whites clamp via geq (safe cross-channel check)
geq_whites="geq=r='if(gte(r(X,Y),$WHITE_T)*gte(g(X,Y),$WHITE_T)*gte(b(X,Y),$WHITE_T),255,r(X,Y))':g='if(gte(r(X,Y),$WHITE_T)*gte(g(X,Y),$WHITE_T)*gte(b(X,Y),$WHITE_T),255,g(X,Y))':b='if(gte(r(X,Y),$WHITE_T)*gte(g(X,Y),$WHITE_T)*gte(b(X,Y),$WHITE_T),255,b(X,Y))'"

# Neutralize bright greys to their average (removes blue cast in greys)
geq_neutral_hi="geq=r='if(gte(r(X,Y),$NEUTRAL_MIN)*gte(g(X,Y),$NEUTRAL_MIN)*gte(b(X,Y),$NEUTRAL_MIN)*lte(abs(r(X,Y)-g(X,Y)),$NEUTRAL_DELTA)*lte(abs(g(X,Y)-b(X,Y)),$NEUTRAL_DELTA),(r(X,Y)+g(X,Y)+b(X,Y))/3,r(X,Y))':g='if(gte(r(X,Y),$NEUTRAL_MIN)*gte(g(X,Y),$NEUTRAL_MIN)*gte(b(X,Y),$NEUTRAL_MIN)*lte(abs(r(X,Y)-g(X,Y)),$NEUTRAL_DELTA)*lte(abs(g(X,Y)-b(X,Y)),$NEUTRAL_DELTA),(r(X,Y)+g(X,Y)+b(X,Y))/3,g(X,Y))':b='if(gte(r(X,Y),$NEUTRAL_MIN)*gte(g(X,Y),$NEUTRAL_MIN)*gte(b(X,Y),$NEUTRAL_MIN)*lte(abs(r(X,Y)-b(X,Y)),$NEUTRAL_DELTA)*lte(abs(g(X,Y)-b(X,Y)),$NEUTRAL_DELTA),(r(X,Y)+g(X,Y)+b(X,Y))/3,b(X,Y))'"

encode_one () {
  local src="$1"
  local stem="${src%.gif}"
  local base="$(basename "$stem")"
  local out="$OUT_DIR/${base}-${TARGET_W}x${TARGET_H}.mp4"

  local tweak=""
  case "$base" in
    5_KA_browser_window_v3_4)
      tweak="colorchannelmixer=rr=${RED_R_SCALE}:gg=${RED_G_SCALE}:bb=${RED_B_SCALE}"
      ;;
    6_MTG_browser_window_v2-2_2)
      tweak="colorchannelmixer=rr=${BLUE_R_SCALE}:gg=${BLUE_G_SCALE}:bb=${BLUE_B_SCALE}"
      ;;
    *)
      echo "Skipping $src (not a red/blue target)"
      return 0
      ;;
  esac

  # RGB → tweak → clamp whites → neutralize greys → 709 limited → scale → yuv420p
  local filters="format=rgba,${tweak},${geq_whites},${geq_neutral_hi},$(geo_chain),format=yuv420p,setsar=1"

  echo "→ MP4  $src  →  $out"
  ffmpeg -v warning -y -i "$src" \
    -vf "$filters" \
    "${FPS_OPTS[@]}" \
    -c:v libx264 -pix_fmt yuv420p -preset "$PRESET_H264" -crf "$CRF_H264" -tune animation \
    -x264-params "$X264_PARAMS" \
    -movflags +faststart -an \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
    "$out"
}

# Run only on files present; only the two basenames above will be encoded
found_any=false
for gif in ./*.gif; do
  [[ -e "$gif" ]] || break
  found_any=true
  encode_one "$gif"
done

$found_any || { echo "No .gif files found here."; exit 0; }
echo "Done. Outputs in: $OUT_DIR"
