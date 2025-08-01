#!/usr/bin/env bash
set -e

# ─── Configuration ────────────────────────────────────────────────────────────

# Breakpoints (max container widths)
BREAKPOINTS=(1000)

# Gap between the two videos (px)
GAP=28

# Pair #1 sources & their original dimensions
# SRC1="CMB_v.mp4";      W1_ORIG=1800; H1_ORIG=3200
# SRC2="CMB_master.mp4"; W2_ORIG=2924; H2_ORIG=3300

# If you want to do the MYDB pair instead, just comment out the CMB lines above
# and uncomment these:
SRC1="Pioneers_master.mp4";      W1_ORIG=2926; H1_ORIG=3300
SRC2="GTB_master.mp4";           W2_ORIG=2924; H2_ORIG=3300

# ─── Derived names & math prep ────────────────────────────────────────────────

base1="${SRC1%.*}"
base2="${SRC2%.*}"

AR1=$(echo "scale=6; $W1_ORIG / $H1_ORIG" | bc)
AR2=$(echo "scale=6; $W2_ORIG / $H2_ORIG" | bc)

mkdir -p bottom2

# ─── Loop through each breakpoint ──────────────────────────────────────────────

for CW in "${BREAKPOINTS[@]}"; do
  # Compute the common height so that (W1 + W2 + GAP) == CW
  H=$(echo "($CW - $GAP) / ($AR1 + $AR2)" | bc -l)
  H=${H%.*}
  H=$(( H / 2 * 2 ))        # force even

  # Compute each width
  W1=$(echo "$AR1 * $H" | bc -l); W1=${W1%.*}; W1=$(( W1 / 2 * 2 ))
  W2=$(( CW - GAP - W1 ))   # automatically even if CW and W1 are even

  echo
  echo "→ container ${CW}px → ${base1}=${W1}×${H}, ${base2}=${W2}×${H}"

  # Build the two MP4s
  ffmpeg -y -i "$SRC1" \
    -vf "scale=${W1}:${H}:flags=lanczos,fps=12" \
    -c:v libx264 -preset slow -crf 18 -tune animation \
    -pix_fmt yuv420p -movflags +faststart -an \
    "bottom2/${base1}-${CW}.mp4"

  ffmpeg -y -i "$SRC2" \
    -vf "scale=${W2}:${H}:flags=lanczos,fps=12" \
    -c:v libx264 -preset slow -crf 18 -tune animation \
    -pix_fmt yuv420p -movflags +faststart -an \
    "bottom2/${base2}-${CW}.mp4"
done