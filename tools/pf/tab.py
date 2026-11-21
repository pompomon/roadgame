"""PF prototype: tabulates measure.mjs results. Usage: python3 tools/pf/tab.py <results.jsonl>...

Each row: the browser, scene, user args and size, the page's frame rate, median and p95 frame
intervals (ms), then the probe's last PERF line: its frame rate, main-thread process, physics and
draw times (ms; draw is mean/max), draw calls, the visible rect, and the frame-interval buckets.
"""

import json
import re
import sys


def field(perf: str, key: str) -> str:
    m = re.search(key + r"=([0-9./]+)", perf)
    return m.group(1) if m else "-"


for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as f:
        for line in f:
            r = json.loads(line)
            p = r.get("perfLast", "")
            vp = re.search(r"vp=\(([0-9.]+), ([0-9.]+)\)", p)
            size = f"{float(vp.group(1)):.0f}x{float(vp.group(2)):.0f}" if vp else "-"
            extra = " ".join(r["extra"])
            print(
                f"{r['browser'][:2]} {r['build']:6} {r['area']:8} h{r['hour']:<2} {extra[:60]:60} "
                f"{r['size']:12} fps {r['fps']:5} med {r['med_ms']:6} p95 {r['p95_ms']:6} | "
                f"probe {field(p, 'fps'):5} proc {field(p, 'proc')} phys {field(p, 'phys')} "
                f"draw {field(p, 'draw'):11} draws {field(p, 'draws'):8} vp {size} "
                f"iv8/17/25/33 {field(p, 'iv8')}/{field(p, 'iv17')}/{field(p, 'iv25')}/{field(p, 'iv33')}"
            )
