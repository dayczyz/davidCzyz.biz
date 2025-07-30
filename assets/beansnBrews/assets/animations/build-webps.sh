#!/usr/bin/env bash
set -e

# build-from-mp4.sh — convert all .mp4 loops into animated WebPs at multiple resolutions

# 1) Target breakpoints (in CSS pixels)
WIDTHS=(500 640 800 1000)

# 2) Make sure output folder exists
mkdir -p optimized

# 3) Loop through every MP4 in this dir
for src in *.mp4; do
  base="${src%.*}"
  for w in "${WIDTHS[@]}"; do
    out="optimized/${base}-${w}.webp"
    echo "→ Generating ${out} from ${src} at ${w}px…"

    ffmpeg -y -i "$src" \
      -vf "fps=12,scale=${w}:-1:flags=lanczos" \
      -c:v libwebp \
      -lossless 0 \
      -q:v 80 \
      -loop 0 \
      -preset picture \
      "$out"
  done
done
