#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")"

# ----- Output & geometry -----
OUT_DIR="${OUT_DIR:-./mp4}"
WIDTHS=(${WIDTHS:-1000 1488})
mkdir -p "$OUT_DIR"

# ----- Timing (keep source timing by default) -----
FORCE_FPS="${FORCE_FPS:-}"
if [[ -n "$FORCE_FPS" ]]; then
  FPS_OPTS=(-fps_mode cfr -r "$FORCE_FPS")
else
  FPS_OPTS=(-fps_mode vfr)
fi

# ----- Encoder quality (a bit richer to protect fades) -----
CRF_H264="${CRF_H264:-14}"            # was 16; lower CRF = more bits for the shadow
PRESET_H264="${PRESET_H264:-veryslow}"
# slightly softer psy + default deblock to reduce ringing/banding
X264_PARAMS='colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off:aq-mode=3:aq-strength=1.10:chroma-qp-offset=-4:deblock=1,1:psy-rd=0.50,0.00'

# =======================
# WHITES / BLACKS GUARDS
# =======================
# Catch cyan-tinted near-whites like 239/255/254
WHITE_STRICT_R="${WHITE_STRICT_R:-236}"
WHITE_STRICT_G="${WHITE_STRICT_G:-254}"
WHITE_STRICT_B="${WHITE_STRICT_B:-254}"

# General near-white → pure white (bright + small spread)
WHITE_NEAR_MIN="${WHITE_NEAR_MIN:-236}"
WHITE_NEAR_DELTA="${WHITE_NEAR_DELTA:-22}"

# Near-black guard (RELAXED so the drop shadow tail isn’t clipped)
ENABLE_BLACK_GUARD="${ENABLE_BLACK_GUARD:-0}" # 0=off (best for soft shadows), 1=on
BLACK_T="${BLACK_T:-2}"

# --- GEQ stages ---
cond_strict="gte(r(X,Y),$WHITE_STRICT_R)*gte(g(X,Y),$WHITE_STRICT_G)*gte(b(X,Y),$WHITE_STRICT_B)"
geq_white_strict="geq=r='if($cond_strict,255,r(X,Y))':g='if($cond_strict,255,g(X,Y))':b='if($cond_strict,255,b(X,Y))'"

min_all="min(min(r(X,Y),g(X,Y)),b(X,Y))"
max_all="max(max(r(X,Y),g(X,Y)),b(X,Y))"
cond_near="gte($min_all,$WHITE_NEAR_MIN)*lte($max_all-$min_all,$WHITE_NEAR_DELTA)"
geq_white_near="geq=r='if($cond_near,255,r(X,Y))':g='if($cond_near,255,g(X,Y))':b='if($cond_near,255,b(X,Y))'"

geq_blacks="geq=r='if(lte(r(X,Y),$BLACK_T)*lte(g(X,Y),$BLACK_T)*lte(b(X,Y),$BLACK_T),0,r(X,Y))':g='if(lte(r(X,Y),$BLACK_T)*lte(g(X,Y),$BLACK_T)*lte(b(X,Y),$BLACK_T),0,g(X,Y))':b='if(lte(r(X,Y),$BLACK_T)*lte(g(X,Y),$BLACK_T)*lte(b(X,Y),$BLACK_T),0,b(X,Y))'"

# Dither style used when mapping to 709 limited (helps smooth fades)
Z_DITHER="${Z_DITHER:-error_diffusion}"   # ordered|random|error_diffusion

# Light deband/dither after 8-bit 4:2:0 (protects gradients)
GRADFUN="${GRADFUN:-gradfun=strength=0.7:radius=16}"

# Gentler scaler (reduces ringing vs lanczos)
SCALER="${SCALER:-spline}"           # try: bicubic

# Luma-only blur + deband to smooth the shadow
BLUR_SIGMA="${BLUR_SIGMA:-0.55}"     # 0.45–0.70 is subtle
GRADF_STRENGTH="${GRADF_STRENGTH:-1.0}"
GRADF_RADIUS="${GRADF_RADIUS:-18}"

# Dithering mode in zscale
Z_DITHER="${Z_DITHER:-error_diffusion}"  # ordered|random|error_diffusion

vf_chain () {
  local W="$1"
  local blacks=""
  [[ "${ENABLE_BLACK_GUARD:-0}" == "1" ]] && blacks="${geq_blacks},"

  # One single line; no backslashes/newlines
  echo "format=rgba,${geq_white_strict},${geq_white_near},${blacks}zscale=primariesin=bt709:transferin=bt709:rangein=pc:primaries=bt709:transfer=bt709:range=limited:dither=${Z_DITHER},scale=${W}:-2:flags=${SCALER}+accurate_rnd+full_chroma_int,format=yuv420p,gblur=sigma=${BLUR_SIGMA}:steps=1:planes=1,gradfun=strength=${GRADF_STRENGTH}:radius=${GRADF_RADIUS},setsar=1"
}    

encode_one () {
  local src="$1"
  local stem="${src%.gif}"
  local base
  base="$(basename "$stem")"

  for W in "${WIDTHS[@]}"; do
    local out="$OUT_DIR/${base}-${W}.mp4"
    echo "→ MP4  $src  →  $out  (W=${W}, keep AR, VFR, shadow-safe)"
    ffmpeg -v warning -y -i "$src" \
      -vf "$(vf_chain "$W")" \
      "${FPS_OPTS[@]}" \
      -c:v libx264 -pix_fmt yuv420p -preset "$PRESET_H264" -crf "$CRF_H264" -tune animation \
      -x264-params "$X264_PARAMS" \
      -movflags +faststart -an \
      -color_primaries bt709 -color_trc bt709 -colorspace bt709 -color_range tv \
      "$out"
  done
}

found=false
for gif in ./*.gif; do
  [[ -e "$gif" ]] || continue
  found=true
  encode_one "$gif"
done

$found || { echo "No .gif files found here."; exit 0; }
echo "Done. Outputs in: $OUT_DIR"
