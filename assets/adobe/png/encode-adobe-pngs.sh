#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"
ROOT="$(pwd -P)"

OUT_BASE="$ROOT/webp"
OUT_OPT="$OUT_BASE/optimized"
mkdir -p "$OUT_BASE" "$OUT_OPT"

# Toggle these when you run it:
CONFIRM="${CONFIRM:-1}"   # 1 = ask “enter to continue” after each image
REVEAL="${REVEAL:-1}"     # 1 = reveal the first file of each image in Finder

echo "Working in:  $ROOT"
echo "Masters  →   $OUT_BASE"
echo "Variants →   $OUT_OPT"

if command -v cwebp >/dev/null 2>&1; then
  ENCODER="cwebp"; echo "Encoder: $(command -v cwebp)"
else
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ERROR: need cwebp or ffmpeg (brew install webp or brew install ffmpeg)" >&2; exit 1
  fi
  ENCODER="ffmpeg"; echo "Encoder: $(command -v ffmpeg) (fallback)"
fi

SIZES=(500 640 800 1100)
LOSSLESS_Z=9
NEAR_LEVEL=97
METHOD=6
ALPHA_Q=100
FF_LOSSLESS="-lossless 1 -compression_level 6 -pix_fmt rgba -quality 100 -alpha_quality 100"
FF_NEAR="-lossless 0 -compression_level 6 -q:v 92 -pix_fmt rgba -alpha_quality 100"

check_file () {
  local f="$1"
  if [[ -s "$f" ]]; then
    printf "   ✓ exists (%s bytes)\n" "$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f")"
    return 0
  else
    echo "   ✗ FAILED to write: $f"
    return 1
  fi
}

encode_one_cwebp () {
  local src="$1" base="$2"

  local master="$OUT_BASE/${base}.webp"
  cwebp -quiet -mt -lossless -z "$LOSSLESS_Z" -exact -metadata icc \
        -alpha_q 100 -alpha_filter best -- "$src" -o "$master"
  echo "✓ $master"; check_file "$master"
  [[ "$REVEAL" == "1" ]] && open -R "$master" || true

  for w in "${SIZES[@]}"; do
    local out="$OUT_OPT/${base}-${w}.webp"
    cwebp -quiet -mt -near_lossless "$NEAR_LEVEL" -z "$LOSSLESS_Z" -exact -metadata icc \
          -alpha_q "$ALPHA_Q" -alpha_filter best -m "$METHOD" \
          -resize "$w" 0 -- "$src" -o "$out"
    echo "  • $out"; check_file "$out"
  done
}

encode_one_ffmpeg () {
  local src="$1" base="$2"
  local master="$OUT_BASE/${base}.webp"
  ffmpeg -v error -y -i "$src" -c:v libwebp $FF_LOSSLESS "$master"
  echo "✓ $master"; check_file "$master"
  [[ "$REVEAL" == "1" ]] && open -R "$master" || true

  for w in "${SIZES[@]}"; do
    local out="$OUT_OPT/${base}-${w}.webp"
    ffmpeg -v error -y -i "$src" -vf "scale=${w}:-1:flags=lanczos" \
           -c:v libwebp $FF_NEAR "$out"
    echo "  • $out"; check_file "$out"
  done
}

any=false
for f in ./*.png ./*.PNG; do
  [[ -e "$f" ]] || continue
  any=true
  stem="${f%.*}"
  base="$(basename "$stem")"
  echo "→ Encoding: $f"
  if [[ "$ENCODER" == "cwebp" ]]; then
    encode_one_cwebp "$f" "$base"
  else
    encode_one_ffmpeg "$f" "$base"
  fi
  if [[ "$CONFIRM" == "1" ]]; then
    read -rp "Press Enter for next image (or type q to quit): " ans
    [[ "${ans:-}" == q* ]] && exit 0
  fi
done

if ! $any; then
  echo "No PNG files found in: $ROOT"; exit 0
fi

echo "Done."
echo "Master count:  $(find "$OUT_BASE" -maxdepth 1 -type f -name '*.webp' | wc -l | tr -d ' ')"
echo "Variant count: $(find "$OUT_OPT"  -maxdepth 1 -type f -name '*.webp' | wc -l | tr -d ' ')"
