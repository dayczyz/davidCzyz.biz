#!/usr/bin/env bash
set -e
shopt -s nullglob

# ─── Configuration ────────────────────────────────────────────────────────────

HEADER_HEIGHT=(813)
HEADER_SRC_DIR="assets/spaghettiOs/png/"
OUTDIR_HEADER="assets/spaghettiOs/webm/header"

# Heights you want for the Big Matrix GIFs → WebM/AV1
BM_HEIGHTS=(400 720)
BM_SRC_DIR="assets/spaghettiOs/webp/bigMatrix"
OUTDIR_BM="assets/spaghettiOs/webm/bigMatrix"

# Heights for the quad-matrix at the bottom
QUAD_HEIGHTS=(400 750)
QUAD_SRC_DIR="assets/spaghettiOs/webp/quadMatrix"
OUTDIR_QUAD="assets/spaghettiOs/webm/quadMatrix"

# Heights for the April-Fools side-by-side GIFs
APRIL_HEIGHTS=(400 720)
APRIL_SRC_DIR="assets/spaghettiOs/webp/aprilFools"
OUTDIR_APRIL="assets/spaghettiOs/webm/aprilFools"

# ─── Core conversion function ─────────────────────────────────────────────────

process_dir() {
  local srcdir="$1" outdir="$2"; shift 2
  local heights=("$@")

  mkdir -p "$outdir"
  for src in "$srcdir"/*.gif; do
    local base=$(basename "$src" .gif)
    for h in "${heights[@]}"; do
      local out="$outdir/${base}-${h}.webm"
      echo "→ Converting ${base}.gif → ${h}px → ${out}"
      ffmpeg -y \
        -i "$src" \
        -vf "fps=12,scale=-2:${h}:flags=lanczos,format=yuv444p" \
        -c:v libaom-av1 \
          -crf 30 -b:v 0 \
          -cpu-used 4 -threads 4 \
        -an \
        "$out"
    done
  done
}

# ─── Run batches ───────────────────────────────────────────────────────────────

# echo "=== Building Big-Matrix AV1/WebM ==="
# process_dir "$BM_SRC_DIR" "$OUTDIR_BM" "${BM_HEIGHTS[@]}"

# echo
# echo "=== Building Quad-Matrix AV1/WebM ==="
# process_dir "$QUAD_SRC_DIR" "$OUTDIR_QUAD" "${QUAD_HEIGHTS[@]}"

# echo
# echo "=== Building April-Fools AV1/WebM ==="
# process_dir "$APRIL_SRC_DIR" "$OUTDIR_APRIL" "${APRIL_HEIGHTS[@]}"

echo
echo "=== Building Header Av1/WebM ==="
process_dir "$HEADER_SRC_DIR" "$OUTDIR_HEADER" "${HEADER_HEIGHT[@]}"

echo
echo "All done! 🎉 AV1/WebM files are in assets/spaghettiOs/webm/"
