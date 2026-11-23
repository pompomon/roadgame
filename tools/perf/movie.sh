#!/usr/bin/env bash
# Record a fresh E4 run at its actual viewport size, not --resolution's cropped middle.
# Usage: movie.sh <new output dir> <area> <hour> <frames> [user args...]
# MOVIE_WIDTH/MOVIE_HEIGHT default to 360/640; 1137/640 reproduces the 1280x720 view at zoom 2.
set -euo pipefail
[ "$#" -ge 4 ] || { echo "usage: movie.sh <new output dir> <area> <hour> <frames> [args...]" >&2; exit 2; }
out=$1 area=$2 hour=$3 frames=$4
shift 4
width=${MOVIE_WIDTH:-360} height=${MOVIE_HEIGHT:-640}
for value in "$width" "$height" "$frames"; do
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || { echo "width, height and frame count must be positive integers" >&2; exit 2; }
done
root=$(cd "$(dirname "$0")/../.." && pwd)
[ ! -e "$out" ] || { echo "output already exists: $out" >&2; exit 2; }
[ ! -e "$root/override.cfg" ] || { echo "override.cfg already exists; refusing to replace it" >&2; exit 2; }
mkdir -p "$out/data"
out=$(cd "$out" && pwd)
trap 'rm -f -- "$root/override.cfg"' EXIT
printf '[display]\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\n' \
  "$width" "$height" > "$root/override.cfg"
XDG_DATA_HOME="$out/data" xvfb-run -a -s "-screen 0 1920x1200x24" "${GODOT:-godot}" \
  --path "$root" --resolution "${width}x${height}" --write-movie "$out/f.png" --fixed-fps 60 \
  --quit-after "$frames" -- --autopilot --seed=1 --area="$area" --hour="$hour" "$@" > "$out/run.log" 2>&1
if grep -nE '(^| )ERROR:|Parse Error|Failed to load script' "$out/run.log"; then
  echo "Movie Maker reported errors: $out/run.log" >&2
  exit 1
fi
python3 - "$out" "$width" "$height" "$frames" <<'PY'
import pathlib
import struct
import sys
directory, width, height, expected = sys.argv[1:]
frames = sorted(pathlib.Path(directory).glob("*.png"))
if len(frames) != int(expected):
    sys.exit(f"Expected {expected} frames, got {len(frames)}")
for frame in frames:
    with frame.open("rb") as source:
        header = source.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", header[16:24]) != (int(width), int(height)):
        sys.exit(f"Unexpected frame size or format: {frame}")
print(f"{directory}: {len(frames)} frames, {width}x{height}, no error lines")
PY
