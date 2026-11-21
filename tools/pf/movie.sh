#!/usr/bin/env bash
# PF prototype: records an autopilot run's frames with Movie Maker, for diff_frames.py.
# Usage: tools/pf/movie.sh <out dir> <area> <hour> <frames> [user args...]
# Needs godot (or GODOT) and xvfb-run. Prints the frame count and the run's error lines.
set -euo pipefail
out=$1 area=$2 hour=$3 frames=$4
shift 4
root=$(cd "$(dirname "$0")/../.." && pwd)
rm -rf "$out"
mkdir -p "$out"
xvfb-run -a -s "-screen 0 1280x1024x24" "${GODOT:-godot}" --path "$root" --resolution 360x640 \
  --write-movie "$out/f.png" --quit-after "$frames" -- --autopilot --seed=1 --area="$area" \
  --hour="$hour" "$@" > "$out.log" 2>&1
echo "$out: $(find "$out" -name '*.png' | wc -l) frames, error lines: $(grep -c 'ERROR' "$out.log" || true)"
