#!/usr/bin/env bash
set -e
shopt -s nullglob

# ─── Configuration ────────────────────────────────────────────────────────────

BM_HEIGHTS=(400 720)
BM_SRC_DIR="assets/spaghettiOs/webp/bigMatrix"
OUTDIR_BM="assets/spaghettiOs/mp4/bigMatrix"

QUAD_HEIGHTS=(400 750)
QUAD_SRC_DIR="assets/spaghettiOs/webp/quadMatrix"
OUTDIR_QUAD="assets/spaghettiOs/mp4/quadMatrix"

APRIL_HEIGHTS=(400 720)
APRIL_SRC_DIR="assets/spaghettiOs/webp/aprilFools"
OUTDIR_APRIL="assets/spaghettiOs/mp4/aprilFools"

# ─── Core conversion function ─────────────────────────────────────────────────

process_dir() {
  local srcdir=$1 outdir=$2; shift 2
  local heights=("$@")

  mkdir -p "$outdir"
  for src in "$srcdir"/*.gif; do
    local base=${src##*/}; base=${base%.gif}
    for h in "${heights[@]}"; do
      local out="$outdir/${base}-${h}.mp4"
      echo "→ Converting $src → height ${h}px → $out (RGB-only)"
      ffmpeg -y \
        -i "$src" \
        -vf "fps=12,scale=-2:${h}:flags=lanczos,format=rgb24" \
        -c:v libx264rgb \
        -crf 0 \
        -preset slow \
        -movflags +faststart \
        -an \
        "$out"
    done
  done
}

# ─── Run all batches ──────────────────────────────────────────────────────────

echo "=== Big-Matrix ==="
process_dir "$BM_SRC_DIR" "$OUTDIR_BM" "${BM_HEIGHTS[@]}"

echo
echo "=== Quad-Matrix ==="
process_dir "$QUAD_SRC_DIR" "$OUTDIR_QUAD" "${QUAD_HEIGHTS[@]}"

echo
echo "=== April-Fools ==="
process_dir "$APRIL_SRC_DIR" "$OUTDIR_APRIL" "${APRIL_HEIGHTS[@]}"

echo
echo "Done! All animations should now preserve your original reds exactly. 🎨"