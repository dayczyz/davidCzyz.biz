#!/usr/bin/env bash
set -e
shopt -s nullglob

# ─── Configuration ────────────────────────────────────────────────────────────

# Heights you want for the Big Matrix Gifs >> mp4s
BM_HEIGHTS=(400 720)

# Source directory
BM_SRC_DIR="assets/spaghettiOs/webp/bigMatrix"


# Output folder for videos
OUTDIR_BM="assets/spaghettiOs/mp4/bigMatrix"

# ─── Quad-matrix configuration ────────────────────────────────────────────────

# Heights for the quad at bottom
QUAD_HEIGHTS=(400 750)
QUAD_SRC_DIR="assets/spaghettiOs/webp/quadMatrix"
OUTDIR_QUAD="assets/spaghettiOs/mp4/quadMatrix"

# --- April-fools configuration ------------------------------------------------

# Heights for the April fools side by side gifs
APRIL_HEIGHTS=(400 720)
APRIL_SRC_DIR="assets/spaghettiOs/webp/aprilFools"
OUTDIR_APRIL="assets/spaghettiOs/mp4/aprilFools"

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Process a single pair of GIFs into two MP4s at each height
# process_pair() {
#   local s1="$1" s2="$2" outdir="$3"
#   shift 3
#   local heights=("$@")

#   mkdir -p "$outdir"
#   for h in "${heights[@]}"; do
#     for src in "$s1" "$s2"; do
#       base=$(basename "$src" .gif)
#       out="$outdir/${base}-${h}.mp4"
#       echo "→ $base → height ${h}px → $out"
#       ffmpeg -y -i "$src" \
#         -vf "scale=-2:${h}:flags=lanczos,fps=12" \
#         -c:v libx264 -preset slow -crf 18 -tune animation \
#         -pix_fmt yuv420p -movflags +faststart -an \
#         "$out"
#     done
#   done
# }

# Process every .gif in a directory into MP4s at given heights
process_dir() {
  local srcdir="$1" outdir="$2"
  shift 2
  local heights=("$@")

  mkdir -p "$outdir"
  for src in "$srcdir"/*.gif; do
    base=$(basename "$src" .gif)
    for h in "${heights[@]}"; do
      out="$outdir/${base}-${h}.mp4"
      echo "→ quad ${base} → height ${h}px → $out"
     ffmpeg -y -i "$src" \
        -vf "scale=-2:${H}:flags=lanczos,fps=12,format=yuv444p" \
        -c:v libx264 \
        -preset slow \
        -crf 18 \
        -tune animation \
        -pix_fmt yuv444p \
        -profile:v high444 \
        -movflags +faststart \
        -an \
        "$out"
    done
  done
}

# ─── Run everything ───────────────────────────────────────────────────────────

echo "=== Building side-by-side pair ==="
process_dir "$BM_SRC_DIR" "$OUTDIR_BM" "${BM_HEIGHTS[@]}"

echo
echo "=== Building quad-matrix MP4 ==="
process_dir "$QUAD_SRC_DIR" "$OUTDIR_QUAD" "${QUAD_HEIGHTS[@]}"

echo
echo "===Building april-fools MP4 ==="
process_dir "$APRIL_SRC_DIR" "$OUTDIR_APRIL" "${APRIL_HEIGHTS[@]}"

echo
echo "All done! 🎉"