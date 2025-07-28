#!/usr/bin/env bash
#
# build-webps.sh — generate 500, 640, 800, 1100-wide animated WebPs

# your breakpoints
WIDTHS=(500 640 800 1100)

# ensure the output folder exists
mkdir -p optimized

# for every .webp in this folder…
for src in *.webp; do
  base="${src%.webp}"
  for w in "${WIDTHS[@]}"; do
    out="optimized/${base}-${w}.webp"
    echo "→ Generating ${out}…"
    # everything on one line, no backslashes or comments in between
    magick "$src" -coalesce -resize "${w}x" -layers Optimize "$out"
  done
done
