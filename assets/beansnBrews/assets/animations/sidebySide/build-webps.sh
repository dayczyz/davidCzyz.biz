#!/usr/bin/env bash
set -e

# target container widths (in CSS pixels)
# we drop 1100 and replace it with the layout max of 1000
BREAKPOINTS=(500 600 800 1000)

# gap between the two videos (in px)
GAP=28

# your two source clips & their original dimensions…
SRC1="CMB_v.mp4";     W1_ORIG=1800; H1_ORIG=3200
SRC2="CMB_master.mp4"; W2_ORIG=2924; H2_ORIG=3300

# compute aspect ratios
AR1=$(echo "scale=6; $W1_ORIG / $H1_ORIG" | bc)
AR2=$(echo "scale=6; $W2_ORIG / $H2_ORIG" | bc)

mkdir -p optimized

for CW in "${BREAKPOINTS[@]}"; do
  # shared height for both clips
  H=$(echo "($CW - $GAP) / ($AR1 + $AR2)" | bc -l)
  H=${H%.*}

  # widths so that W1 + W2 + GAP == CW
  W1=$(echo "$AR1 * $H" | bc -l); W1=${W1%.*}
  W2=$(( CW - GAP - W1 ))

  echo
  echo "→ container ${CW}px: height ${H}px"
  echo "   • clip1 → ${W1}×${H}"
  echo "   • clip2 → ${W2}×${H}"

  ffmpeg -y -i "$SRC1" -vf "scale=${W1}:${H}:flags=lanczos,fps=12" \
    -c:v libwebp -lossless 0 -q:v 85 -loop 0 "optimized/CMBv_${CW}.webp"

  ffmpeg -y -i "$SRC2" -vf "scale=${W2}:${H}:flags=lanczos,fps=12" \
    -c:v libwebp -lossless 0 -q:v 85 -loop 0 "optimized/CMBmaster_${CW}.webp"
done