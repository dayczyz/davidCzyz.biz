#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
cd "$(dirname "$0")"

OUT_DIR="${OUT_DIR:-./optimized}"
SIZES=(${SIZES:-500 640 800 1100 1920})
mkdir -p "$OUT_DIR"

command -v sips >/dev/null 2>&1 || { echo "Need macOS 'sips'."; exit 1; }

get_w(){ sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/{print $2}'; }
lower(){ printf "%s" "$1" | tr '[:upper:]' '[:lower:]'; }

process_one () {
  local src="$1"
  local base="${src##*/}"
  local name="${base%.*}"
  local ext_lc; ext_lc="$(lower "${base##*.}")"
  local wsrc; wsrc="$(get_w "$src")"

  for W in "${SIZES[@]}"; do
    local out="$OUT_DIR/${name}-${W}.${ext_lc}"

    # Don’t upscale: if source narrower than target, just copy with profile intact.
    if (( wsrc <= W )); then
      cp -f "$src" "$out"
      echo "→ copy (no upscale)  $out"
      continue
    fi

    if [[ "$ext_lc" == "png" ]]; then
      # PNG stays lossless; sips preserves ICC
      sips --resampleWidth "$W" -s format png "$src" --out "$out" >/dev/null
    else
      # JPEG: best quality, 4:4:4; preserves ICC
      sips --resampleWidth "$W" -s format jpeg -s formatOptions best "$src" --out "$out" >/dev/null
    fi
    echo "✓ ${W}px  $out"
  done
}

any=false
for f in ./*.{png,PNG,jpg,JPG,jpeg,JPEG}; do
  [[ -e "$f" ]] || continue
  any=true
  process_one "$f"
done

$any || { echo "No PNG/JPEG files found here."; exit 0; }
echo "Done. Variants in: $OUT_DIR"
