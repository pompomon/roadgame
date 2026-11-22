"""Compare every pixel of two movie.sh recordings, failing on missing or differing frames.

Usage: python3 tools/perf/diff_frames.py <dir a> <dir b>. Needs numpy and Pillow.
"""

import os
import sys

import numpy as np
from PIL import Image


def frames(directory: str) -> list[str]:
    return sorted(name for name in os.listdir(directory) if name.endswith(".png"))


a, b = sys.argv[1], sys.argv[2]
fa, fb = frames(a), frames(b)
if not fa or fa != fb:
    sys.exit(f"Frame sets differ or are empty: {len(fa)} versus {len(fb)}")
same = 0
diffs = []
for name in fa:
    x = np.asarray(Image.open(os.path.join(a, name)).convert("RGBA"), dtype=np.int16)
    y = np.asarray(Image.open(os.path.join(b, name)).convert("RGBA"), dtype=np.int16)
    if x.shape != y.shape:
        sys.exit(f"Frame dimensions differ: {name}, {x.shape}, {y.shape}")
    difference = np.abs(x - y)
    pixels = int((difference.max(axis=2) > 0).sum())
    if pixels == 0:
        same += 1
    else:
        diffs.append((name, pixels, int(difference.max())))
print(f"{len(fa)} frames, {same} identical, {len(diffs)} differ")
for frame in sorted(diffs, key=lambda item: -item[1])[:8]:
    print("  ", frame)
sys.exit(1 if diffs else 0)
