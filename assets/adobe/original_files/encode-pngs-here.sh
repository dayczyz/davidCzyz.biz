#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

cd "$(dirname "$0")"
ROOT="$(pwd -P)"

OUT_BASE="$ROOT/webp"
OUT_OPT="$OUT_BASE/optimized"
mkdir -p "$OUT_BASE" "$OUT_OPT"

echo "Working in:  $ROOT"
echo "Masters  →   $OUT_BASE"
echo "Variants →   $OUT_OPT"

command -v ffmpeg >/dev/null || { echo "ERROR: ffmpeg not found (brew install ffmpeg)"; exit 1; }

# Master = true lossless (banding-free). Variants = near-lossless (very high quality).
SIZES=(500 640 800 1100)
FF_LOSSLESS=(-c:v libwebp -lossless 1 -compression_level 6 -quality 100 -alpha_quality 100)
FF_NEAR=(-c:v libwebp -lossless 0 -compression_level 6 -q:v 100 -alpha_quality 100)

encode_one () {
  local src="$1"
  local base="$(basename "${src%.*}")"

  # master
  local master="$OUT_BASE/${base}.webp"
  ffmpeg -v error -y -i "$src" "${FF_LOSSLESS[@]}" "$master"
  [[ -s "$master" ]] && echo "✓ $master" || { echo "✗ failed: $master"; return 1; }

  # variants
  for w in "${SIZES[@]}"; do
    local out="$OUT_OPT/${base}-${w}.webp"
    ffmpeg -v error -y -i "$src" -vf "scale=${w}:-1:flags=lanczos" "${FF_NEAR[@]}" "$out"
    [[ -s "$out" ]] && echo "  • $out" || echo "  ✗ failed: $out"
  done
}

any=false
for f in ./*.png ./*.PNG ./*.jpg; do
  [[ -e "$f" ]] || continue
  any=true
  encode_one "$f"
done

$any || { echo "No PNG files found in: $ROOT"; exit 0; }

echo "Done."
echo "Master count:  $(find "$OUT_BASE" -maxdepth 1 -name '*.webp' -type f | wc -l | tr -d ' ')"
echo "Variant count: $(find "$OUT_OPT"  -maxdepth 1 -name '*.webp' -type f | wc -l | tr -d ' ')"
