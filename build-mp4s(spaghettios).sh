#!/usr/bin/env bash
set -e
shopt -s nullglob

# ─── Configuration ────────────────────────────────────────────────────────────

# Heights you want for the Big Matrix GIFs → MP4s
BM_HEIGHTS=(400 720)
BM_SRC_DIR="assets/spaghettiOs/webp/bigMatrix"
OUTDIR_BM="assets/spaghettiOs/mp4/bigMatrix"

# Heights for the quad-matrix at the bottom
QUAD_HEIGHTS=(400 750)
QUAD_SRC_DIR="assets/spaghettiOs/webp/quadMatrix"
OUTDIR_QUAD="assets/spaghettiOs/mp4/quadMatrix"

# Heights for the April Fools side-by-side GIFs
APRIL_HEIGHTS=(400 720)
APRIL_SRC_DIR="assets/spaghettiOs/webp/aprilFools"
OUTDIR_APRIL="assets/spaghettiOs/mp4/aprilFools"

# ─── Helper to process a directory of .gif → .mp4 ───────────────────────────────
process_dir() {
  local srcdir="$1" outdir="$2"
  shift 2
  local heights=("$@")

  mkdir -p "$outdir"
  for src in "$srcdir"/*.gif; do
    local base=$(basename "$src" .gif)
    for h in "${heights[@]}"; do
      local out="$outdir/${base}-${h}.mp4"
      echo "→ ${base} @ ${h}px → ${out}"
      ffmpeg -y \
        -i "$src" \
        -vf "fps=12,scale=-2:${h}:flags=lanczos" \
        -c:v libx264 -preset slow -crf 18 -tune animation \
        -pix_fmt yuv420p -movflags +faststart \
        -an \
        "$out"
    done
  done
}

# ─── Run everything ───────────────────────────────────────────────────────────

echo "=== Building Big-Matrix MP4s ==="
process_dir "$BM_SRC_DIR" "$OUTDIR_BM" "${BM_HEIGHTS[@]}"

echo
echo "=== Building Quad-Matrix MP4s ==="
process_dir "$QUAD_SRC_DIR" "$OUTDIR_QUAD" "${QUAD_HEIGHTS[@]}"

echo
echo "=== Building April-Fools MP4s ==="
process_dir "$APRIL_SRC_DIR" "$OUTDIR_APRIL" "${APRIL_HEIGHTS[@]}"

echo
echo "All done! 🎉"