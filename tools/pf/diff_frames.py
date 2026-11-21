"""PF prototype: compares two movie.sh recordings frame by frame.

Usage: python3 tools/pf/diff_frames.py <dir a> <dir b>. Needs numpy and Pillow. Prints how many
frames are pixel-identical, and for the others the count of differing pixels and the largest
channel difference.
"""

import os
import sys

import numpy as np
from PIL import Image


def frames(d: str) -> list[str]:
    return sorted(f for f in os.listdir(d) if f.endswith(".png"))


a, b = sys.argv[1], sys.argv[2]
fa, fb = frames(a), frames(b)
n = min(len(fa), len(fb))
same = 0
diffs = []
for i in range(n):
    x = np.asarray(Image.open(os.path.join(a, fa[i])).convert("RGB"), dtype=np.int16)
    y = np.asarray(Image.open(os.path.join(b, fb[i])).convert("RGB"), dtype=np.int16)
    if x.shape != y.shape:
        print("shape", fa[i], x.shape, y.shape)
        continue
    d = np.abs(x - y)
    px = int((d.max(axis=2) > 0).sum())
    if px == 0:
        same += 1
    else:
        diffs.append((fa[i], px, int(d.max())))
print(f"{n} frames, {same} identical, {len(diffs)} differ")
for f in sorted(diffs, key=lambda t: -t[1])[:8]:
    print("  ", f)
